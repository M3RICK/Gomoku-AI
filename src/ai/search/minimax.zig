const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const movegen = @import("../../game/movegen.zig");
const rules = @import("../../game/rules.zig");
const timer = @import("timer.zig");
const evaluate = @import("../evaluation/position.zig");
const move_ordering = @import("../optimization/move_ordering.zig");
const transposition = @import("../optimization/transposition.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

const SCORE_MIN: i32 = -1_000_000;
const SCORE_MAX: i32 = 1_000_000;
const SCORE_WIN: i32 = 100_000;
const DEPTH_LIMIT: i32 = 10;

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

fn searchAtDepth(board: *Board, depth: i32, ctx: SearchContext) !SearchResult {
    var gen = movegen.MoveGenerator.init(ctx.allocator);
    const moves = try gen.generateSmart(board, 2);
    defer ctx.allocator.free(moves);
    defer gen.deinit();

    if (moves.len == 0) return error.NoMovesAvailable;

    try move_ordering.orderMoves(board, moves, ctx.player);

    var best = moves[0];
    var top_score = SCORE_MIN;

    for (moves) |m| {
        if (timer.isTimeUp(ctx.deadline)) return error.TimeUp;

        board_mod.makeMove(board, m.x, m.y, ctx.player);
        var next_ctx = ctx;
        next_ctx.hash = transposition.updateHash(ctx.hash, m.x, m.y, ctx.player);
        const eval = try minimax(board, depth - 1, SCORE_MIN, SCORE_MAX, false, next_ctx);
        board_mod.undoMove(board, m.x, m.y);

        if (eval > top_score) {
            top_score = eval;
            best = m;
        }
    }

    return SearchResult{ .move = best, .score = top_score };
}

fn minimax(
    board: *Board,
    depth: i32,
    alpha: i32,
    beta: i32,
    maximizing: bool,
    ctx: SearchContext,
) error{ OutOfMemory, TimeUp }!i32 {
    if (timer.isTimeUp(ctx.deadline)) {
        return error.TimeUp;
    }

    if (ctx.tt.probe(ctx.hash)) |entry| {
        if (entry.depth >= depth) {
            return entry.score;
        }
    }

    if (depth == 0) {
        return evaluate.evaluateForBothPlayers(board);
    }

    if (board.move_count > 0 and checkTerminalState(board)) {
        return if (maximizing) -SCORE_WIN else SCORE_WIN;
    }

    if (maximizing) {
        return try minimaxMax(board, depth, alpha, beta, ctx);
    } else {
        return try minimaxMin(board, depth, alpha, beta, ctx);
    }
}

fn minimaxMax(board: *Board, depth: i32, a: i32, b: i32, ctx: SearchContext) !i32 {
    var alpha = a;
    var best_val = SCORE_MIN;

    var gen = movegen.MoveGenerator.init(ctx.allocator);
    const moves = try gen.generateSmart(board, 2);
    defer ctx.allocator.free(moves);
    defer gen.deinit();

    if (moves.len == 0) return 0;

    try move_ordering.orderMoves(board, moves, ctx.player);

    for (moves) |m| {
        board_mod.makeMove(board, m.x, m.y, ctx.player);
        var next_ctx = ctx;
        next_ctx.hash = transposition.updateHash(ctx.hash, m.x, m.y, ctx.player);
        const val = try minimax(board, depth - 1, alpha, b, false, next_ctx);
        board_mod.undoMove(board, m.x, m.y);

        best_val = @max(best_val, val);
        alpha = @max(alpha, val);

        if (b <= alpha) break;
    }

    return best_val;
}

fn minimaxMin(board: *Board, depth: i32, a: i32, b: i32, ctx: SearchContext) !i32 {
    var beta = b;
    var best_val = SCORE_MAX;
    const opp = board_mod.getOpponent(ctx.player);

    var gen = movegen.MoveGenerator.init(ctx.allocator);
    const moves = try gen.generateSmart(board, 2);
    defer ctx.allocator.free(moves);
    defer gen.deinit();

    if (moves.len == 0) return 0;

    try move_ordering.orderMoves(board, moves, opp);

    for (moves) |m| {
        board_mod.makeMove(board, m.x, m.y, opp);
        var next_ctx = ctx;
        next_ctx.hash = transposition.updateHash(ctx.hash, m.x, m.y, opp);
        const val = try minimax(board, depth - 1, a, beta, true, next_ctx);
        board_mod.undoMove(board, m.x, m.y);

        best_val = @min(best_val, val);
        beta = @min(beta, val);

        if (beta <= a) break;
    }

    return best_val;
}

fn getFallbackMove(board: *const Board, allocator: std.mem.Allocator) !Move {
    var gen = movegen.MoveGenerator.init(allocator);
    const moves = try gen.generateSmart(board, 2);

    const move = if (moves.len > 0) moves[0] else Move.init(board.size / 2, board.size / 2);

    allocator.free(moves);
    gen.deinit();
    return move;
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
