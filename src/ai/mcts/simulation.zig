const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const movegen = @import("../../game/movegen.zig");
const rules = @import("../../game/rules.zig");
const threat = @import("../evaluation/threat.zig");
const evaluate = @import("../evaluation/position.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

const MAX_SIMULATION_MOVES = 25;

pub const SimulationResult = enum {
    player_win,
    opponent_win,
    draw,
};

pub fn simulate(
    board: *Board,
    starting_player: Cell,
    allocator: std.mem.Allocator,
) !SimulationResult {
    var move_count: usize = 0;
    var current_player = starting_player;

    while (move_count < MAX_SIMULATION_MOVES) {
        const move = try selectSimulationMove(board, current_player, allocator);

        if (move == null) {
            return evaluatePosition(board, starting_player);
        }

        board_mod.makeMove(board, move.?.x, move.?.y, current_player);

        const has_won = rules.checkWin(board, move.?.x, move.?.y);
        if (has_won) {
            const result = getResultForPlayer(current_player, starting_player);
            return result;
        }

        current_player = board_mod.getOpponent(current_player);
        move_count += 1;
    }

    return evaluatePosition(board, starting_player);
}

fn selectSimulationMove(
    board: *Board,
    player: Cell,
    allocator: std.mem.Allocator,
) !?Move {
    var gen = movegen.MoveGenerator.init(allocator);
    defer gen.deinit();

    const moves = try gen.generateSmart(board, 1);
    defer allocator.free(moves);

    if (moves.len == 0) {
        return null;
    }

    const winning_move = findWinningMove(board, moves, player);
    if (winning_move != null) {
        return winning_move;
    }

    const blocking_move = findBlockingMove(board, moves, player);
    if (blocking_move != null) {
        return blocking_move;
    }

    const open_four_move = findOpenFourMove(board, moves, player);
    if (open_four_move != null) {
        return open_four_move;
    }

    return selectWeightedRandomMove(board, moves);
}

fn findWinningMove(board: *Board, moves: []Move, player: Cell) ?Move {
    for (moves) |m| {
        const is_winning = threat.isWinningMove(board, m, player);
        if (is_winning) {
            return m;
        }
    }
    return null;
}

fn findBlockingMove(board: *Board, moves: []Move, player: Cell) ?Move {
    for (moves) |m| {
        const is_blocking = threat.isBlockingWin(board, m, player);
        if (is_blocking) {
            return m;
        }
    }
    return null;
}

fn findOpenFourMove(board: *Board, moves: []Move, player: Cell) ?Move {
    for (moves) |m| {
        const creates_four = threat.createsOpenFour(board, m, player);
        if (creates_four) {
            return m;
        }
    }
    return null;
}

fn selectWeightedRandomMove(board: *const Board, moves: []Move) Move {
    if (moves.len == 1) {
        return moves[0];
    }

    var best_move = moves[0];
    var best_distance = getDistanceFromCenter(board, moves[0]);

    for (moves[1..]) |m| {
        const distance = getDistanceFromCenter(board, m);
        if (distance < best_distance) {
            best_distance = distance;
            best_move = m;
        }
    }

    return best_move;
}

fn getDistanceFromCenter(board: *const Board, move: Move) usize {
    const center = board.size / 2;
    const dx = if (move.x > center) move.x - center else center - move.x;
    const dy = if (move.y > center) move.y - center else center - move.y;
    return dx + dy;
}

fn getResultForPlayer(winner: Cell, original_player: Cell) SimulationResult {
    if (winner == original_player) {
        return .player_win;
    }
    return .opponent_win;
}

fn evaluatePosition(board: *const Board, player: Cell) SimulationResult {
    const score = evaluate.evaluateForBothPlayers(board);

    const threshold: i32 = 5000;

    if (score > threshold) {
        if (player == .me) {
            return .player_win;
        }
        return .opponent_win;
    }

    if (score < -threshold) {
        if (player == .me) {
            return .opponent_win;
        }
        return .player_win;
    }

    return .draw;
}

pub fn getWinValue(result: SimulationResult) f32 {
    return switch (result) {
        .player_win => 1.0,
        .opponent_win => 0.0,
        .draw => 0.5,
    };
}
