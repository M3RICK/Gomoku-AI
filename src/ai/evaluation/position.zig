const std = @import("std");
const board_mod = @import("../../game/board.zig");
const pattern = @import("pattern.zig");
const direction = @import("../../game/direction.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;

pub fn evaluatePosition(board: *const Board, player: Cell) i32 {
    var score: i32 = 0;

    for (0..board.size) |x| {
        score += evaluateLine(board, x, 0, pattern.HORIZONTAL, player);
    }

    for (0..board.size) |y| {
        score += evaluateLine(board, 0, y, pattern.VERTICAL, player);
    }

    for (0..board.size) |x| {
        score += evaluateLine(board, x, 0, pattern.DIAGONAL, player);
    }
    for (1..board.size) |y| {
        score += evaluateLine(board, 0, y, pattern.DIAGONAL, player);
    }

    for (0..board.size) |y| {
        score += evaluateLine(board, 0, y, pattern.ANTI_DIAGONAL, player);
    }
    for (1..board.size) |x| {
        score += evaluateLine(board, x, board.size - 1, pattern.ANTI_DIAGONAL, player);
    }

    return score;
}

fn evaluateLine(board: *const Board, start_x: usize, start_y: usize, dir: direction.Direction, player: Cell) i32 {
    var total: i32 = 0;
    var pos_x: i32 = @intCast(start_x);
    var pos_y: i32 = @intCast(start_y);

    var active = false;
    var length: usize = 0;
    var left_open = false;
    var right_open = false;

    while (direction.isValidPosition(board, pos_x, pos_y)) {
        const cell = board_mod.getCell(board, @intCast(pos_x), @intCast(pos_y));

        if (cell == player) {
            if (!active) {
                active = true;
                length = 1;
                left_open = checkSpaceOpen(board, pos_x - dir.dx, pos_y - dir.dy);
            } else {
                length += 1;
            }
        } else {
            if (active) {
                right_open = (cell == .empty);
                total += scoreSequence(length, left_open, right_open);
                active = false;
            }
        }

        pos_x += dir.dx;
        pos_y += dir.dy;
    }

    if (active) {
        total += scoreSequence(length, left_open, false);
    }

    return total;
}

fn checkSpaceOpen(board: *const Board, x: i32, y: i32) bool {
    if (!direction.isValidPosition(board, x, y)) {
        return false;
    }
    return board_mod.getCell(board, @intCast(x), @intCast(y)) == .empty;
}

fn scoreSequence(len: usize, left: bool, right: bool) i32 {
    const info = pattern.LineInfo{
        .count = len,
        .open_left = left,
        .open_right = right,
    };
    return pattern.scorePattern(info);
}

pub fn evaluateForBothPlayers(board: *const Board) i32 {
    const my_score = evaluatePosition(board, .me);
    const opponent_score = evaluatePosition(board, .opponent);

    const defense_weight = calculateDefenseWeight(opponent_score);
    const weighted_opponent = @divTrunc(opponent_score * defense_weight, 10);

    return my_score - weighted_opponent;
}

fn calculateDefenseWeight(opponent_score: i32) i32 {
    if (opponent_score > 90_000) {
        return 13;
    }
    if (opponent_score > 50_000) {
        return 11;
    }
    return 10;
}

test "position eval" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    board_mod.makeMove(&board, 10, 10, .me);
    board_mod.makeMove(&board, 10, 11, .me);
    board_mod.makeMove(&board, 10, 12, .me);

    const score = evaluatePosition(&board, .me);
    try std.testing.expect(score > 0);
}
