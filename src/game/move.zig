const std = @import("std");
const board_mod = @import("board.zig");
const Board = board_mod.Board;

pub const Move = struct {
    x: usize,
    y: usize,

    pub fn init(x: usize, y: usize) Move {
        return Move{ .x = x, .y = y };
    }
};

pub fn isLegal(board: *const Board, x: usize, y: usize) bool {
    if (!board_mod.isInBounds(board, x, y)) {
        return false;
    }
    return board_mod.isEmpty(board, x, y);
}

pub fn isValidMove(board: *const Board, move: Move) bool {
    return isLegal(board, move.x, move.y);
}

pub fn getCenter(board: *const Board) Move {
    const center = board.size / 2;
    return Move.init(center, center);
}

fn countEmptyInRow(board: *const Board, row: usize) usize {
    var count: usize = 0;
    for (0..board.size) |col| {
        if (board_mod.isEmpty(board, row, col)) {
            count += 1;
        }
    }
    return count;
}

pub fn countAvailable(board: *const Board) usize {
    var total: usize = 0;
    for (0..board.size) |row| {
        total += countEmptyInRow(board, row);
    }
    return total;
}

test "move validation" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    try std.testing.expect(isLegal(&board, 10, 10));

    board_mod.makeMove(&board, 10, 10, .me);
    try std.testing.expect(!isLegal(&board, 10, 10));
}
