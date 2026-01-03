const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const movegen = @import("../../game/movegen.zig");
const evaluate = @import("../evaluation/position.zig");
const threat = @import("../evaluation/threat.zig");
const timer = @import("timer.zig");
const transposition = @import("../optimization/transposition.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

const MAX_QUIESCE_DEPTH = 4;
const TACTICAL_THREAT_THRESHOLD = 48_000;

pub fn search(
    board: *Board,
    alpha: i32,
    beta: i32,
    player: Cell,
    hash: u64,
    deadline: i64,
    allocator: std.mem.Allocator,
) error{ OutOfMemory, TimeUp }!i32 {
    return searchTacticalMoves(
        board,
        alpha,
        beta,
        player,
        hash,
        deadline,
        allocator,
        MAX_QUIESCE_DEPTH,
    );
}

fn searchTacticalMoves(
    board: *Board,
    alpha_bound: i32,
    beta_bound: i32,
    player: Cell,
    hash: u64,
    deadline: i64,
    allocator: std.mem.Allocator,
    remaining_depth: i32,
) error{ OutOfMemory, TimeUp }!i32 {
    if (shouldStopSearch(deadline, remaining_depth)) {
        const static_score = getStaticEvaluation(board);
        return static_score;
    }

    const current_eval = getStaticEvaluation(board);

    if (canPruneBeta(current_eval, beta_bound)) {
        return beta_bound;
    }

    const final_score = try searchAllTacticalMoves(
        board,
        alpha_bound,
        beta_bound,
        current_eval,
        player,
        hash,
        deadline,
        allocator,
        remaining_depth,
    );

    return final_score;
}

fn getStaticEvaluation(board: *const Board) i32 {
    return evaluate.evaluateForBothPlayers(board);
}

fn canPruneBeta(score: i32, beta: i32) bool {
    return score >= beta;
}

fn searchAllTacticalMoves(
    board: *Board,
    alpha_bound: i32,
    beta_bound: i32,
    baseline_eval: i32,
    player: Cell,
    hash: u64,
    deadline: i64,
    allocator: std.mem.Allocator,
    remaining_depth: i32,
) !i32 {
    var best_score = improveLowerBound(alpha_bound, baseline_eval);

    const tactical_moves = try getTacticalMoves(board, player, allocator);
    defer allocator.free(tactical_moves);

    if (noTacticalMovesAvailable(tactical_moves)) {
        return baseline_eval;
    }

    for (tactical_moves) |move| {
        const move_score = try evaluateSingleMove(
            board,
            move,
            player,
            best_score,
            beta_bound,
            hash,
            deadline,
            allocator,
            remaining_depth,
        );

        if (shouldCutoff(move_score, beta_bound)) {
            return beta_bound;
        }

        best_score = updateBestScore(best_score, move_score);
    }

    return best_score;
}

fn shouldStopSearch(deadline: i64, depth: i32) bool {
    return timer.isTimeUp(deadline) or depth == 0;
}

fn improveLowerBound(alpha: i32, baseline: i32) i32 {
    return @max(alpha, baseline);
}

fn noTacticalMovesAvailable(moves: []Move) bool {
    return moves.len == 0;
}

fn shouldCutoff(score: i32, beta: i32) bool {
    return score >= beta;
}

fn updateBestScore(current_best: i32, new_score: i32) i32 {
    return @max(current_best, new_score);
}

fn evaluateSingleMove(
    board: *Board,
    move: Move,
    player: Cell,
    alpha: i32,
    beta: i32,
    hash: u64,
    deadline: i64,
    allocator: std.mem.Allocator,
    depth: i32,
) !i32 {
    board_mod.makeMove(board, move.x, move.y, player);
    defer board_mod.undoMove(board, move.x, move.y);

    const enemy_score = try getOpponentResponse(
        board,
        move,
        player,
        alpha,
        beta,
        hash,
        deadline,
        allocator,
        depth,
    );

    return -enemy_score;
}

fn getOpponentResponse(
    board: *Board,
    move: Move,
    player: Cell,
    alpha: i32,
    beta: i32,
    hash: u64,
    deadline: i64,
    allocator: std.mem.Allocator,
    depth: i32,
) !i32 {
    const next_hash = transposition.updateHash(hash, move.x, move.y, player);
    const opponent = board_mod.getOpponent(player);

    return try searchTacticalMoves(
        board,
        -beta,
        -alpha,
        opponent,
        next_hash,
        deadline,
        allocator,
        depth - 1,
    );
}

fn getTacticalMoves(board: *Board, player: Cell, allocator: std.mem.Allocator) ![]Move {
    const all_moves = try generateCandidateMoves(board, allocator);
    defer allocator.free(all_moves);

    return try filterTacticalMoves(board, all_moves, player, allocator);
}

fn generateCandidateMoves(board: *const Board, allocator: std.mem.Allocator) ![]Move {
    var gen = movegen.MoveGenerator.init(allocator);
    defer gen.deinit();

    return try gen.generateSmart(board, 2);
}

fn filterTacticalMoves(
    board: *Board,
    all_moves: []Move,
    player: Cell,
    allocator: std.mem.Allocator,
) ![]Move {
    var tactical_moves: std.ArrayList(Move) = .empty;
    errdefer tactical_moves.deinit(allocator);

    for (all_moves) |move| {
        if (isTacticalMove(board, move, player)) {
            try tactical_moves.append(allocator, move);
        }
    }

    return tactical_moves.toOwnedSlice(allocator);
}

fn isTacticalMove(board: *Board, move: Move, player: Cell) bool {
    if (isImmediateWin(board, move, player)) {
        return true;
    }

    if (blocksOpponentWin(board, move, player)) {
        return true;
    }

    if (createsDangerousThreat(board, move, player)) {
        return true;
    }

    return false;
}

fn isImmediateWin(board: *Board, move: Move, player: Cell) bool {
    return threat.isWinningMove(board, move, player);
}

fn blocksOpponentWin(board: *Board, move: Move, player: Cell) bool {
    return threat.isBlockingWin(board, move, player);
}

fn createsDangerousThreat(board: *Board, move: Move, player: Cell) bool {
    const threat_score = threat.scoreThreatCreation(board, move, player);
    return threat_score > TACTICAL_THREAT_THRESHOLD;
}
