const std = @import("std");

pub const Cell = enum {
    empty,
    me,
    opponent,
};

pub const Board = struct {
    cells: [][]Cell,
    size: usize,
    move_count: usize,
    allocator: std.mem.Allocator,
};

pub fn init(allocator: std.mem.Allocator, size: usize) !Board {
    const cells = try allocator.alloc([]Cell, size);
    for (cells) |*row| {
        row.* = try allocator.alloc(Cell, size);
        for (row.*) |*cell| {
            cell.* = .empty;
        }
    }

    return Board{
        .cells = cells,
        .size = size,
        .move_count = 0,
        .allocator = allocator,
    };
}

pub fn deinit(board: *Board) void {
    for (board.cells) |row| {
        board.allocator.free(row);
    }
    board.allocator.free(board.cells);
}

pub fn makeMove(board: *Board, x: usize, y: usize, player: Cell) void {
    board.cells[x][y] = player;
    board.move_count += 1;
}

pub fn undoMove(board: *Board, x: usize, y: usize) void {
    board.cells[x][y] = .empty;
    if (board.move_count > 0) {
        board.move_count -= 1;
    }
}

pub fn getCell(board: *const Board, x: usize, y: usize) Cell {
    return board.cells[x][y];
}

pub fn isEmpty(board: *const Board, x: usize, y: usize) bool {
    return board.cells[x][y] == .empty;
}

pub fn isInBounds(board: *const Board, x: usize, y: usize) bool {
    return x < board.size and y < board.size;
}

pub fn isFull(board: *const Board) bool {
    return board.move_count >= (board.size * board.size);
}

pub fn clear(board: *Board) void {
    for (board.cells) |row| {
        for (row) |*cell| {
            cell.* = .empty;
        }
    }
    board.move_count = 0;
}

pub fn clone(board: *const Board) !Board {
    var new_board = try init(board.allocator, board.size);
    for (board.cells, 0..) |row, i| {
        for (row, 0..) |cell, j| {
            new_board.cells[i][j] = cell;
        }
    }
    new_board.move_count = board.move_count;
    return new_board;
}

// Tests

test "board initialization" {
    const allocator = std.testing.allocator;
    var board = try init(allocator, 20);
    defer deinit(&board);

    try std.testing.expectEqual(@as(usize, 20), board.size);
    try std.testing.expectEqual(@as(usize, 0), board.move_count);
    try std.testing.expectEqual(Cell.empty, getCell(&board, 0, 0));
    try std.testing.expectEqual(Cell.empty, getCell(&board, 19, 19));
}

test "make and undo move" {
    const allocator = std.testing.allocator;
    var board = try init(allocator, 20);
    defer deinit(&board);

    makeMove(&board, 10, 10, .me);
    try std.testing.expectEqual(Cell.me, getCell(&board, 10, 10));
    try std.testing.expectEqual(@as(usize, 1), board.move_count);

    undoMove(&board, 10, 10);
    try std.testing.expectEqual(Cell.empty, getCell(&board, 10, 10));
    try std.testing.expectEqual(@as(usize, 0), board.move_count);
}

test "isEmpty check" {
    const allocator = std.testing.allocator;
    var board = try init(allocator, 20);
    defer deinit(&board);

    try std.testing.expect(isEmpty(&board, 10, 10));

    makeMove(&board, 10, 10, .me);
    try std.testing.expect(!isEmpty(&board, 10, 10));
}

test "isInBounds check" {
    const allocator = std.testing.allocator;
    var board = try init(allocator, 20);
    defer deinit(&board);

    try std.testing.expect(isInBounds(&board, 0, 0));
    try std.testing.expect(isInBounds(&board, 19, 19));
    try std.testing.expect(!isInBounds(&board, 20, 20));
    try std.testing.expect(!isInBounds(&board, 30, 15));
}

test "board clear" {
    const allocator = std.testing.allocator;
    var board = try init(allocator, 20);
    defer deinit(&board);

    makeMove(&board, 5, 5, .me);
    makeMove(&board, 10, 10, .opponent);
    try std.testing.expectEqual(@as(usize, 2), board.move_count);

    clear(&board);
    try std.testing.expectEqual(@as(usize, 0), board.move_count);
    try std.testing.expect(isEmpty(&board, 5, 5));
    try std.testing.expect(isEmpty(&board, 10, 10));
}

test "board clone" {
    const allocator = std.testing.allocator;
    var board = try init(allocator, 20);
    defer deinit(&board);

    makeMove(&board, 10, 10, .me);
    makeMove(&board, 11, 11, .opponent);

    var cloned = try clone(&board);
    defer deinit(&cloned);

    try std.testing.expectEqual(board.size, cloned.size);
    try std.testing.expectEqual(board.move_count, cloned.move_count);
    try std.testing.expectEqual(Cell.me, getCell(&cloned, 10, 10));
    try std.testing.expectEqual(Cell.opponent, getCell(&cloned, 11, 11));
}
