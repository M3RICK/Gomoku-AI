const board_mod = @import("board.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;

pub const Direction = struct {
    dx: i32,
    dy: i32,
};

pub const HORIZONTAL = Direction{ .dx = 1, .dy = 0 };
pub const VERTICAL = Direction{ .dx = 0, .dy = 1 };
pub const DIAGONAL = Direction{ .dx = 1, .dy = 1 };
pub const ANTI_DIAGONAL = Direction{ .dx = 1, .dy = -1 };

pub const DirectionResult = struct {
    stones: usize,
    is_open: bool,
};

pub fn isValidPosition(board: *const Board, x: i32, y: i32) bool {
    if (x < 0 or y < 0) {
        return false;
    }
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    return board_mod.isInBounds(board, ux, uy);
}

pub fn countDirection(
    board: *const Board,
    x: usize,
    y: usize,
    dx: i32,
    dy: i32,
    player: Cell,
) DirectionResult {
    var count: usize = 0;
    var open = false;

    var px: i32 = @intCast(x);
    var py: i32 = @intCast(y);

    while (true) {
        px += dx;
        py += dy;

        if (!isValidPosition(board, px, py)) break;

        const cell = getCellAt(board, px, py);
        if (cell == player) {
            count += 1;
        } else if (cell == .empty) {
            open = true;
            break;
        } else {
            break;
        }
    }

    return DirectionResult{ .stones = count, .is_open = open };
}

fn getCellAt(board: *const Board, x: i32, y: i32) Cell {
    return board_mod.getCell(board, @intCast(x), @intCast(y));
}
