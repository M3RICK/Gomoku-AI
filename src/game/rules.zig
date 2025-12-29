const std = @import("std");
const board_mod = @import("board.zig");
const direction = @import("direction.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;

const HORIZONTAL = direction.HORIZONTAL;
const VERTICAL = direction.VERTICAL;
const DIAGONAL = direction.DIAGONAL;
const ANTI_DIAGONAL = direction.ANTI_DIAGONAL;

const WINNING_LENGTH = 5;

pub fn checkWin(board: *const Board, x: usize, y: usize) bool {
    const player = board_mod.getCell(board, x, y);
    if (player == .empty) {
        return false;
    }

    if (checkDirection(board, x, y, player, HORIZONTAL))
        return true;
    if (checkDirection(board, x, y, player, VERTICAL))
        return true;
    if (checkDirection(board, x, y, player, DIAGONAL))
        return true;
    if (checkDirection(board, x, y, player, ANTI_DIAGONAL))
        return true;

    return false;
}

fn checkDirection(board: *const Board, x: usize, y: usize, player: Cell, dir: direction.Direction) bool {
    const count = countLine(board, x, y, player, dir);
    return count >= WINNING_LENGTH;
}

fn countLine(board: *const Board, x: usize, y: usize, player: Cell, dir: direction.Direction) usize {
    var total: usize = 1;

    total += direction.countDirection(board, x, y, dir.dx, dir.dy, player).stones;
    total += direction.countDirection(board, x, y, -dir.dx, -dir.dy, player).stones;

    return total;
}

pub fn isGameOver(board: *const Board, last_x: usize, last_y: usize) bool {
    return checkWin(board, last_x, last_y) or board_mod.isFull(board);
}

test "win detection" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    // horizontal
    board_mod.makeMove(&board, 10, 10, .me);
    board_mod.makeMove(&board, 10, 11, .me);
    board_mod.makeMove(&board, 10, 12, .me);
    board_mod.makeMove(&board, 10, 13, .me);
    board_mod.makeMove(&board, 10, 14, .me);
    try std.testing.expect(checkWin(&board, 10, 12));

    board_mod.clear(&board);

    // diagonal
    board_mod.makeMove(&board, 10, 10, .me);
    board_mod.makeMove(&board, 11, 11, .me);
    board_mod.makeMove(&board, 12, 12, .me);
    board_mod.makeMove(&board, 13, 13, .me);
    board_mod.makeMove(&board, 14, 14, .me);
    try std.testing.expect(checkWin(&board, 12, 12));
}

test "no win with 4 stones" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    board_mod.makeMove(&board, 10, 10, .me);
    board_mod.makeMove(&board, 10, 11, .me);
    board_mod.makeMove(&board, 10, 12, .me);
    board_mod.makeMove(&board, 10, 13, .me);

    try std.testing.expect(!checkWin(&board, 10, 13));
}
