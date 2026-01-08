const std = @import("std");
const board_mod = @import("../../game/board.zig");
const direction = @import("../../game/direction.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;

// ============================================================================
// Enums
// ============================================================================

pub const Openness = enum {
    closed,
    semi_open,
    open,
};

// ============================================================================
// Structs
// ============================================================================

pub const AdvancedLineInfo = struct {
    count: usize,
    openness: Openness,
};

const Position = struct {
    x: i32,
    y: i32,

    fn init(ux: usize, uy: usize) Position {
        return Position{
            .x = @intCast(ux),
            .y = @intCast(uy),
        };
    }

    fn step(self: Position, dir: direction.Direction) Position {
        return Position{
            .x = self.x + dir.dx,
            .y = self.y + dir.dy,
        };
    }

    fn isValid(self: Position, board: *const Board) bool {
        return direction.isValidPosition(board, self.x, self.y);
    }

    fn toUsize(self: Position) struct { x: usize, y: usize } {
        return .{
            .x = @intCast(self.x),
            .y = @intCast(self.y),
        };
    }
};

// ============================================================================
// Public Functions
// ============================================================================

pub fn scanAdvancedLine(
    board: *const Board,
    x: usize,
    y: usize,
    dir: direction.Direction,
    player: Cell,
) AdvancedLineInfo {
    var count: usize = 1;

    const left = direction.countDirection(board, x, y, -dir.dx, -dir.dy, player);
    const right = direction.countDirection(board, x, y, dir.dx, dir.dy, player);

    count += left.stones;
    count += right.stones;

    const openness = determineOpenness(left.is_open, right.is_open);

    return AdvancedLineInfo{
        .count = count,
        .openness = openness,
    };
}

pub fn createsSemiOpenFour(
    board: *const Board,
    x: usize,
    y: usize,
    player: Cell,
) bool {
    const dirs = getAllDirections();

    for (dirs) |dir| {
        const info = scanAdvancedLine(board, x, y, dir, player);

        if (isSemiOpenFour(info)) {
            return true;
        }
    }

    return false;
}

pub fn countBrokenThrees(board: *const Board, x: usize, y: usize, player: Cell) usize {
    var total: usize = 0;
    const dirs = getAllDirections();

    for (dirs) |dir| {
        if (hasBrokenThreeInDirection(board, x, y, dir, player)) {
            total += 1;
        }
    }

    return total;
}

pub fn countBrokenFours(board: *const Board, x: usize, y: usize, player: Cell) usize {
    var total: usize = 0;
    const dirs = getAllDirections();

    for (dirs) |dir| {
        if (hasBrokenFourInDirection(board, x, y, dir, player)) {
            total += 1;
        }
    }

    return total;
}

pub fn createsBrokenFour(board: *const Board, x: usize, y: usize, player: Cell) bool {
    const dirs = getAllDirections();

    for (dirs) |dir| {
        if (hasBrokenFourInDirection(board, x, y, dir, player)) {
            return true;
        }
    }

    return false;
}

pub fn scoreAdvancedPattern(info: AdvancedLineInfo) i32 {
    const safe_count = @min(info.count, 5);
    const scores = getScoreTable();
    const openness_idx = getOpennessIndex(info.openness);
    return scores[safe_count][openness_idx];
}

// ============================================================================
// Helper Functions
// ============================================================================

fn determineOpenness(left_open: bool, right_open: bool) Openness {
    if (left_open and right_open) {
        return .open;
    }
    if (left_open or right_open) {
        return .semi_open;
    }
    return .closed;
}

fn isSemiOpenFour(info: AdvancedLineInfo) bool {
    const is_four = info.count == 4;
    const is_semi = info.openness == .semi_open;
    return is_four and is_semi;
}

fn hasBrokenThreeInDirection(
    board: *const Board,
    x: usize,
    y: usize,
    dir: direction.Direction,
    player: Cell,
) bool {
    if (hasPatternXX_X(board, x, y, dir, player)) {
        return true;
    }
    if (hasPatternX_XX(board, x, y, dir, player)) {
        return true;
    }

    const rev_dir = direction.Direction{ .dx = -dir.dx, .dy = -dir.dy };
    if (hasPatternXX_X(board, x, y, rev_dir, player)) {
        return true;
    }
    if (hasPatternX_XX(board, x, y, rev_dir, player)) {
        return true;
    }

    return false;
}

fn hasBrokenFourInDirection(
    board: *const Board,
    x: usize,
    y: usize,
    dir: direction.Direction,
    player: Cell,
) bool {
    if (hasPatternXXX_X(board, x, y, dir, player)) {
        return true;
    }
    if (hasPatternXX_XX(board, x, y, dir, player)) {
        return true;
    }
    if (hasPatternX_XXX(board, x, y, dir, player)) {
        return true;
    }

    const rev_dir = direction.Direction{ .dx = -dir.dx, .dy = -dir.dy };
    if (hasPatternXXX_X(board, x, y, rev_dir, player)) {
        return true;
    }
    if (hasPatternXX_XX(board, x, y, rev_dir, player)) {
        return true;
    }
    if (hasPatternX_XXX(board, x, y, rev_dir, player)) {
        return true;
    }

    return false;
}

fn hasPatternXX_X(
    board: *const Board,
    x: usize,
    y: usize,
    dir: direction.Direction,
    player: Cell,
) bool {
    const p0 = Position.init(x, y);
    const p1 = p0.step(dir);
    const p2 = p1.step(dir);
    const p3 = p2.step(dir);

    if (!p0.isValid(board)) {
        return false;
    }
    if (!p1.isValid(board)) {
        return false;
    }
    if (!p2.isValid(board)) {
        return false;
    }
    if (!p3.isValid(board)) {
        return false;
    }

    if (!cellMatches(board, p0, player)) {
        return false;
    }
    if (!cellMatches(board, p1, player)) {
        return false;
    }
    if (!isEmpty(board, p2)) {
        return false;
    }
    if (!cellMatches(board, p3, player)) {
        return false;
    }

    return true;
}

fn hasPatternX_XX(
    board: *const Board,
    x: usize,
    y: usize,
    dir: direction.Direction,
    player: Cell,
) bool {
    const p0 = Position.init(x, y);
    const p1 = p0.step(dir);
    const p2 = p1.step(dir);
    const p3 = p2.step(dir);

    if (!p0.isValid(board)) {
        return false;
    }
    if (!p1.isValid(board)) {
        return false;
    }
    if (!p2.isValid(board)) {
        return false;
    }
    if (!p3.isValid(board)) {
        return false;
    }

    if (!cellMatches(board, p0, player)) {
        return false;
    }
    if (!isEmpty(board, p1)) {
        return false;
    }
    if (!cellMatches(board, p2, player)) {
        return false;
    }
    if (!cellMatches(board, p3, player)) {
        return false;
    }

    return true;
}

fn hasPatternXXX_X(
    board: *const Board,
    x: usize,
    y: usize,
    dir: direction.Direction,
    player: Cell,
) bool {
    const p0 = Position.init(x, y);
    const p1 = p0.step(dir);
    const p2 = p1.step(dir);
    const p3 = p2.step(dir);
    const p4 = p3.step(dir);

    if (!p0.isValid(board)) {
        return false;
    }
    if (!p1.isValid(board)) {
        return false;
    }
    if (!p2.isValid(board)) {
        return false;
    }
    if (!p3.isValid(board)) {
        return false;
    }
    if (!p4.isValid(board)) {
        return false;
    }

    if (!cellMatches(board, p0, player)) {
        return false;
    }
    if (!cellMatches(board, p1, player)) {
        return false;
    }
    if (!cellMatches(board, p2, player)) {
        return false;
    }
    if (!isEmpty(board, p3)) {
        return false;
    }
    if (!cellMatches(board, p4, player)) {
        return false;
    }

    return true;
}

fn hasPatternXX_XX(
    board: *const Board,
    x: usize,
    y: usize,
    dir: direction.Direction,
    player: Cell,
) bool {
    const p0 = Position.init(x, y);
    const p1 = p0.step(dir);
    const p2 = p1.step(dir);
    const p3 = p2.step(dir);
    const p4 = p3.step(dir);

    if (!p0.isValid(board)) {
        return false;
    }
    if (!p1.isValid(board)) {
        return false;
    }
    if (!p2.isValid(board)) {
        return false;
    }
    if (!p3.isValid(board)) {
        return false;
    }
    if (!p4.isValid(board)) {
        return false;
    }

    if (!cellMatches(board, p0, player)) {
        return false;
    }
    if (!cellMatches(board, p1, player)) {
        return false;
    }
    if (!isEmpty(board, p2)) {
        return false;
    }
    if (!cellMatches(board, p3, player)) {
        return false;
    }
    if (!cellMatches(board, p4, player)) {
        return false;
    }

    return true;
}

fn hasPatternX_XXX(
    board: *const Board,
    x: usize,
    y: usize,
    dir: direction.Direction,
    player: Cell,
) bool {
    const p0 = Position.init(x, y);
    const p1 = p0.step(dir);
    const p2 = p1.step(dir);
    const p3 = p2.step(dir);
    const p4 = p3.step(dir);

    if (!p0.isValid(board)) {
        return false;
    }
    if (!p1.isValid(board)) {
        return false;
    }
    if (!p2.isValid(board)) {
        return false;
    }
    if (!p3.isValid(board)) {
        return false;
    }
    if (!p4.isValid(board)) {
        return false;
    }

    if (!cellMatches(board, p0, player)) {
        return false;
    }
    if (!isEmpty(board, p1)) {
        return false;
    }
    if (!cellMatches(board, p2, player)) {
        return false;
    }
    if (!cellMatches(board, p3, player)) {
        return false;
    }
    if (!cellMatches(board, p4, player)) {
        return false;
    }

    return true;
}

fn getScoreTable() [6][3]i32 {
    return [6][3]i32{
        [_]i32{ 0, 0, 0 },
        [_]i32{ 0, 0, 0 },
        [_]i32{ 50, 200, 500 },
        [_]i32{ 1_000, 5_000, 15_000 },
        [_]i32{ 10_000, 60_000, 100_000 },
        [_]i32{ 500_000, 500_000, 500_000 },
    };
}

fn getOpennessIndex(openness: Openness) usize {
    return switch (openness) {
        .closed => 0,
        .semi_open => 1,
        .open => 2,
    };
}

fn getAllDirections() [4]direction.Direction {
    return [_]direction.Direction{
        direction.HORIZONTAL,
        direction.VERTICAL,
        direction.DIAGONAL,
        direction.ANTI_DIAGONAL,
    };
}

fn cellMatches(board: *const Board, pos: Position, player: Cell) bool {
    const coords = pos.toUsize();
    const cell = board_mod.getCell(board, coords.x, coords.y);
    return cell == player;
}

fn isEmpty(board: *const Board, pos: Position) bool {
    const coords = pos.toUsize();
    const cell = board_mod.getCell(board, coords.x, coords.y);
    return cell == .empty;
}

// ============================================================================
// Tests
// ============================================================================

test "broken three pattern detection" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    board_mod.makeMove(&board, 10, 10, .me);
    board_mod.makeMove(&board, 10, 11, .me);
    board_mod.makeMove(&board, 10, 13, .me);

    const count = countBrokenThrees(&board, 10, 10, .me);
    try std.testing.expect(count > 0);
}
