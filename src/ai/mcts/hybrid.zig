const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const movegen = @import("../../game/movegen.zig");
const threat = @import("../evaluation/threat.zig");
const mcts_search = @import("search.zig");
const minimax = @import("../search/minimax.zig");
const transposition = @import("../optimization/transposition.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

const EARLY_GAME_MOVES = 15;
const MID_GAME_MOVES = 25;
const TACTICAL_THREAT_SCORE = 50_000;

pub const Strategy = enum {
    mcts,
    minimax,
};

pub fn selectStrategy(board: *const Board) Strategy {
    const is_tactical = isTacticalPosition(board);
    if (is_tactical) {
        return .minimax;
    }

    const move_count = board.move_count;

    if (move_count < EARLY_GAME_MOVES) {
        return .mcts;
    }

    if (move_count >= MID_GAME_MOVES) {
        return .minimax;
    }

    return .mcts;
}

pub fn findBestMove(
    board: *Board,
    time_limit_ms: u32,
    tt: *transposition.TranspositionTable,
    player: Cell,
    allocator: std.mem.Allocator,
) !Move {
    const strategy = selectStrategy(board);

    return switch (strategy) {
        .mcts => try useMCTS(board, player, time_limit_ms, allocator),
        .minimax => try useMinimax(board, time_limit_ms, tt, player, allocator),
    };
}

fn useMCTS(
    board: *Board,
    player: Cell,
    time_limit_ms: u32,
    allocator: std.mem.Allocator,
) !Move {
    return try mcts_search.findBestMove(board, player, time_limit_ms, allocator);
}

fn useMinimax(
    board: *Board,
    time_limit_ms: u32,
    tt: *transposition.TranspositionTable,
    player: Cell,
    allocator: std.mem.Allocator,
) !Move {
    return try minimax.findBestMove(board, time_limit_ms, tt, player, allocator);
}

fn isTacticalPosition(board: *const Board) bool {
    const allocator = std.heap.page_allocator;
    var gen = movegen.MoveGenerator.init(allocator);
    defer gen.deinit();

    const moves = gen.generateSmart(board, 2) catch return false;
    defer allocator.free(moves);

    if (hasImmediateWinOrBlock(board, moves)) {
        return true;
    }

    if (hasOpenFourThreat(board, moves)) {
        return true;
    }

    if (hasSignificantThreat(board, moves)) {
        return true;
    }

    return false;
}

fn hasImmediateWinOrBlock(board: *const Board, moves: []Move) bool {
    var board_copy = board.*;

    for (moves) |m| {
        if (threat.isWinningMove(&board_copy, m, .me)) {
            return true;
        }

        if (threat.isWinningMove(&board_copy, m, .opponent)) {
            return true;
        }
    }

    return false;
}

fn hasOpenFourThreat(board: *const Board, moves: []Move) bool {
    var board_copy = board.*;

    for (moves) |m| {
        if (threat.createsOpenFour(&board_copy, m, .me)) {
            return true;
        }

        if (threat.createsOpenFour(&board_copy, m, .opponent)) {
            return true;
        }
    }

    return false;
}

fn hasSignificantThreat(board: *const Board, moves: []Move) bool {
    var board_copy = board.*;

    for (moves) |m| {
        const my_threat = threat.scoreThreatCreation(&board_copy, m, .me);
        if (my_threat >= TACTICAL_THREAT_SCORE) {
            return true;
        }

        const opp_threat = threat.scoreThreatCreation(&board_copy, m, .opponent);
        if (opp_threat >= TACTICAL_THREAT_SCORE) {
            return true;
        }
    }

    return false;
}

pub fn getStrategyName(board: *const Board) []const u8 {
    const strategy = selectStrategy(board);
    return switch (strategy) {
        .mcts => "MCTS",
        .minimax => "Minimax",
    };
}

pub fn printStrategyChoice(board: *const Board) void {
    const name = getStrategyName(board);
    const moves = board.move_count;
    std.debug.print("Using {s} strategy (move {d})\n", .{ name, moves });
}
