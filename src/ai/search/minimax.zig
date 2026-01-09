const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const movegen = @import("../../game/movegen.zig");
const rules = @import("../../game/rules.zig");
const timer = @import("timer.zig");
const evaluate = @import("../evaluation/position.zig");
const move_ordering = @import("../optimization/move_ordering.zig");
const transposition = @import("../optimization/transposition.zig");
const quiescence = @import("quiescence.zig");
const threat = @import("../evaluation/threat.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

const SCORE_MIN: i32 = -1_000_000;
const SCORE_MAX: i32 = 1_000_000;
const SCORE_WIN: i32 = 100_000;
const SCORE_OPEN_FOUR: i32 = SCORE_WIN - 100;
const SCORE_BLOCK_WIN: i32 = SCORE_WIN - 1;
const SCORE_BLOCK_OPEN_FOUR: i32 = SCORE_WIN - 200;
const DEPTH_LIMIT: i32 = 14;

const SearchError = error{ OutOfMemory, TimeUp };

pub const SearchContext = struct {
    deadline: i64,
    tt: *transposition.TranspositionTable,
    player: Cell,
    allocator: std.mem.Allocator,
    hash: u64,
};

pub const SearchResult = struct {
    move: Move,
    score: i32,
};

pub fn findBestMove(
    board: *Board,
    time_limit_ms: u32,
    tt: *transposition.TranspositionTable,
    player: Cell,
    allocator: std.mem.Allocator,
) !Move {
    const deadline = timer.getDeadline(time_limit_ms);
    const hash = transposition.computeHash(board);
    const ctx = SearchContext{
        .deadline = deadline,
        .tt = tt,
        .player = player,
        .allocator = allocator,
        .hash = hash,
    };
    return try iterativeDeepening(board, ctx);
}

fn iterativeDeepening(board: *Board, ctx: SearchContext) !Move {
    var best: Move = undefined;
    var current_depth: i32 = 1;
    var has_move = false;

    while (current_depth <= DEPTH_LIMIT) : (current_depth += 1) {
        if (timer.isTimeUp(ctx.deadline)) break;

        const result = searchAtDepth(board, current_depth, ctx) catch |err| {
            if (err == error.TimeUp) break;
            return err;
        };

        best = result.move;
        has_move = true;

        if (!timer.shouldContinueToNextDepth(ctx.deadline, current_depth)) break;
    }

    if (!has_move) {
        best = try getFallbackMove(board, ctx.allocator);
    }

    return best;
}

fn narrowMovesIfCritical(board: *Board, all_moves: []Move, player: Cell, allocator: std.mem.Allocator) !?[]Move {
    const opponent = board_mod.getOpponent(player);

    for (all_moves) |m| {
        if (threat.isWinningMove(board, m, opponent)) {
            return try getCriticalMoves(board, all_moves, player, allocator);
        }
        if (threat.createsOpenFour(board, m, opponent)) {
            return try getCriticalMoves(board, all_moves, player, allocator);
        }
    }

    return null;
}

fn getCriticalMoves(board: *Board, all_moves: []Move, player: Cell, allocator: std.mem.Allocator) ![]Move {
    var critical = std.ArrayList(Move){};
    errdefer critical.deinit(allocator);

    for (all_moves) |m| {
        if (threat.isWinningMove(board, m, player)) {
            try critical.append(allocator, m);
            continue;
        }
        if (threat.isBlockingWin(board, m, player)) {
            try critical.append(allocator, m);
            continue;
        }
        if (threat.createsOpenFour(board, m, player)) {
            try critical.append(allocator, m);
            continue;
        }
        const opponent = board_mod.getOpponent(player);
        if (threat.createsOpenFour(board, m, opponent)) {
            try critical.append(allocator, m);
        }
    }

    if (critical.items.len > 0) {
        return try critical.toOwnedSlice(allocator);
    }

    critical.deinit(allocator);
    return try allocator.dupe(Move, all_moves);
}

fn searchAtDepth(board: *Board, depth: i32, ctx: SearchContext) !SearchResult {
    var gen = movegen.MoveGenerator.init(ctx.allocator);
    const all_moves = try gen.generateSmart(board, 2);
    defer gen.deinit();

    if (all_moves.len == 0) {
        ctx.allocator.free(all_moves);
        return error.NoMovesAvailable;
    }

    const critical_moves = try narrowMovesIfCritical(board, all_moves, ctx.player, ctx.allocator);
    const moves = critical_moves orelse all_moves;
    defer ctx.allocator.free(moves);
    if (critical_moves != null) {
        ctx.allocator.free(all_moves);
    }

    try move_ordering.orderMoves(board, moves, ctx.player, ctx.allocator);
    const opponent = board_mod.getOpponent(ctx.player);

    const winning_move = checkForImmediateWin(board, moves, ctx.player);
    if (winning_move) |move| {
        var result: SearchResult = undefined;
        result.move = move;
        result.score = SCORE_WIN;
        return result;
    }

    const open_four_move = checkForOpenFour(board, moves, ctx.player);
    if (open_four_move) |move| {
        var result: SearchResult = undefined;
        result.move = move;
        result.score = SCORE_OPEN_FOUR;
        return result;
    }

    const block_win_move = checkForImmediateWin(board, moves, opponent);
    if (block_win_move) |move| {
        var result: SearchResult = undefined;
        result.move = move;
        result.score = SCORE_BLOCK_WIN;
        return result;
    }

    const block_open_four_move = checkForOpenFour(board, moves, opponent);
    if (block_open_four_move) |move| {
        var result: SearchResult = undefined;
        result.move = move;
        result.score = SCORE_BLOCK_OPEN_FOUR;
        return result;
    }

    return try findBestMoveAtDepth(board, moves, depth, ctx);
}

fn checkForImmediateWin(board: *Board, moves: []Move, player: Cell) ?Move {
    for (moves) |m| {
        if (threat.isWinningMove(board, m, player)) {
            return m;
        }
    }
    return null;
}

fn checkForOpenFour(board: *Board, moves: []Move, player: Cell) ?Move {
    for (moves) |m| {
        if (threat.createsOpenFour(board, m, player)) {
            return m;
        }
    }
    return null;
}

fn findBestMoveAtDepth(board: *Board, moves: []Move, depth: i32, ctx: SearchContext) !SearchResult {
    var best = moves[0];
    var top_score = SCORE_MIN;

    for (moves) |m| {
        if (timer.isTimeUp(ctx.deadline)) {
            return error.TimeUp;
        }

        const score = try evaluateMove(board, m, depth, ctx);
        if (score > top_score) {
            top_score = score;
            best = m;
        }
    }

    return SearchResult{ .move = best, .score = top_score };
}

fn evaluateMove(board: *Board, move: Move, depth: i32, ctx: SearchContext) !i32 {
    board_mod.makeMove(board, move.x, move.y, ctx.player);
    defer board_mod.undoMove(board, move.x, move.y);

    var next_ctx = ctx;
    next_ctx.hash = transposition.updateHash(ctx.hash, move.x, move.y, ctx.player);
    return try minimax(board, depth - 1, SCORE_MIN, SCORE_MAX, false, next_ctx);
}

fn minimax(
    board: *Board,
    depth: i32,
    alpha: i32,
    beta: i32,
    maximizing: bool,
    ctx: SearchContext,
) SearchError!i32 {
    if (timer.isTimeUp(ctx.deadline)) {
        return error.TimeUp;
    }

    if (ctx.tt.probe(ctx.hash)) |entry| {
        if (entry.depth >= depth) {
            return entry.score;
        }
    }

    if (depth == 0) {
        return quiescence.search(
            board,
            alpha,
            beta,
            ctx.player,
            ctx.hash,
            ctx.deadline,
            ctx.allocator,
        ) catch evaluate.evaluateForBothPlayers(board);
    }

    if (board.move_count > 0 and checkTerminalState(board)) {
        return if (maximizing) -SCORE_WIN else SCORE_WIN;
    }

    if (shouldTryNullMove(depth, board.move_count, maximizing)) {
        const null_cutoff = try tryNullMovePruning(board, depth, alpha, beta, ctx);
        if (null_cutoff) |score| {
            return score;
        }
    }

    if (maximizing) {
        return try minimaxMax(board, depth, alpha, beta, ctx);
    } else {
        return try minimaxMin(board, depth, alpha, beta, ctx);
    }
}

fn minimaxMax(board: *Board, depth: i32, a: i32, b: i32, ctx: SearchContext) !i32 {
    const result = try searchMax(board, depth, a, b, ctx);
    saveToCache(ctx, result.move, result.score, depth, a, b);
    return result.score;
}

fn minimaxMin(board: *Board, depth: i32, a: i32, b: i32, ctx: SearchContext) !i32 {
    const opp = board_mod.getOpponent(ctx.player);
    const result = try searchMin(board, depth, a, b, ctx, opp);
    saveToCache(ctx, result.move, result.score, depth, a, b);
    return result.score;
}

fn shouldTryNullMove(depth: i32, move_count: usize, maximizing: bool) bool {
    if (maximizing) return false;
    if (depth < 3) return false;
    if (move_count <= 4) return false;
    return true;
}

fn tryNullMovePruning(
    board: *Board,
    depth: i32,
    alpha: i32,
    beta: i32,
    ctx: SearchContext,
) !?i32 {
    const reduction: i32 = 2;
    const reduced_depth = depth - 1 - reduction;

    const null_score = try minimax(board, reduced_depth, alpha, beta, true, ctx);

    if (null_score >= beta) {
        return beta;
    }

    return null;
}

const SearchResult2 = struct {
    move: Move,
    score: i32,
};

fn searchMax(
    board: *Board,
    depth: i32,
    a: i32,
    b: i32,
    ctx: SearchContext,
) !SearchResult2 {
    var gen = movegen.MoveGenerator.init(ctx.allocator);
    const moves = try gen.generateSmart(board, 2);
    defer ctx.allocator.free(moves);
    defer gen.deinit();

    if (moves.len == 0) {
        return SearchResult2{ .move = Move.init(0, 0), .score = 0 };
    }

    try move_ordering.orderMoves(board, moves, ctx.player, ctx.allocator);

    var best_move = moves[0];
    var best_score = SCORE_MIN;
    var alpha = a;

    for (moves, 0..) |m, move_index| {
        var search_depth = depth;

        if (shouldReduceMove(move_index, depth)) {
            search_depth = depth - 1;
        }

        const score = try tryMoveAndEvaluate(board, m, ctx.player, search_depth, alpha, b, false, ctx);

        if (score > best_score) {
            best_score = score;
            best_move = m;
        }

        alpha = @max(alpha, score);
        if (b <= alpha) {
            break;
        }
    }

    return SearchResult2{ .move = best_move, .score = best_score };
}

fn searchMin(
    board: *Board,
    depth: i32,
    a: i32,
    b: i32,
    ctx: SearchContext,
    player: Cell,
) !SearchResult2 {
    var gen = movegen.MoveGenerator.init(ctx.allocator);
    const moves = try gen.generateSmart(board, 2);
    defer ctx.allocator.free(moves);
    defer gen.deinit();

    if (moves.len == 0) {
        return SearchResult2{ .move = Move.init(0, 0), .score = 0 };
    }

    try move_ordering.orderMoves(board, moves, player, ctx.allocator);

    var best_move = moves[0];
    var best_score = SCORE_MAX;
    var beta = b;

    for (moves, 0..) |m, move_index| {
        var search_depth = depth;

        if (shouldReduceMove(move_index, depth)) {
            search_depth = depth - 1;
        }

        const score = try tryMoveAndEvaluate(board, m, player, search_depth, a, beta, true, ctx);

        if (score < best_score) {
            best_score = score;
            best_move = m;
        }

        beta = @min(beta, score);
        if (beta <= a) {
            break;
        }
    }

    return SearchResult2{ .move = best_move, .score = best_score };
}

fn tryMoveAndEvaluate(
    board: *Board,
    move: Move,
    player: Cell,
    depth: i32,
    alpha: i32,
    beta: i32,
    next_maximizing: bool,
    ctx: SearchContext,
) !i32 {
    board_mod.makeMove(board, move.x, move.y, player);
    defer board_mod.undoMove(board, move.x, move.y);

    var next_ctx = ctx;
    next_ctx.hash = transposition.updateHash(ctx.hash, move.x, move.y, player);
    return try minimax(board, depth - 1, alpha, beta, next_maximizing, next_ctx);
}

fn saveToCache(ctx: SearchContext, best_move: Move, score: i32, depth: i32, original_alpha: i32, beta: i32) void {
    const node_type = if (score <= original_alpha)
        transposition.NodeType.upper_bound
    else if (score >= beta)
        transposition.NodeType.lower_bound
    else
        transposition.NodeType.exact;

    ctx.tt.store(ctx.hash, best_move, score, depth, node_type);
}

fn getFallbackMove(board: *const Board, allocator: std.mem.Allocator) !Move {
    var gen = movegen.MoveGenerator.init(allocator);
    const moves = try gen.generateSmart(board, 2);

    const move = if (moves.len > 0) moves[0] else Move.init(board.size / 2, board.size / 2);

    allocator.free(moves);
    gen.deinit();
    return move;
}

fn shouldReduceMove(move_index: usize, depth: i32) bool {
    if (depth < 3) {
        return false;
    }

    if (move_index < 4) {
        return false;
    }

    return true;
}

fn checkTerminalState(board: *const Board) bool {
    for (0..board.size) |x| {
        for (0..board.size) |y| {
            if (board_mod.getCell(board, x, y) != .empty) {
                if (rules.checkWin(board, x, y)) {
                    return true;
                }
            }
        }
    }
    return false;
}

test "search finds winning move" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    board_mod.deinit(&board);

    board_mod.makeMove(&board, 10, 10, .me);
    board_mod.makeMove(&board, 10, 11, .me);
    board_mod.makeMove(&board, 10, 12, .me);
    board_mod.makeMove(&board, 10, 13, .me);

    var tt = try transposition.TranspositionTable.init(allocator);
    transposition.initZobrist();

    const move = try findBestMove(&board, 1000, &tt, .me, allocator);
    try std.testing.expectEqual(@as(usize, 10), move.x);

    tt.deinit();
}
