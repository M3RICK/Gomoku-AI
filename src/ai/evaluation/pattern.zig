const std = @import("std");
const board_mod = @import("../../game/board.zig");
const direction = @import("../../game/direction.zig");
const advanced = @import("advanced_patterns.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;

pub const HORIZONTAL = direction.HORIZONTAL;
pub const VERTICAL = direction.VERTICAL;
pub const DIAGONAL = direction.DIAGONAL;
pub const ANTI_DIAGONAL = direction.ANTI_DIAGONAL;

pub const LineInfo = struct {
    count: usize,
    open_left: bool,
    open_right: bool,
};

pub fn scanLine(
    board: *const Board,
    x: usize,
    y: usize,
    dir: direction.Direction,
    player: Cell,
) LineInfo {
    var count: usize = 1;

    const left = direction.countDirection(board, x, y, -dir.dx, -dir.dy, player);
    const right = direction.countDirection(board, x, y, dir.dx, dir.dy, player);

    count += left.stones;
    count += right.stones;

    return LineInfo{
        .count = count,
        .open_left = left.is_open,
        .open_right = right.is_open,
    };
}

const SCORES = [6][3]i32{
    [_]i32{ 0, 0, 0 },
    [_]i32{ 0, 0, 0 },
    [_]i32{ 50, 200, 500 },
    [_]i32{ 1_000, 5_000, 50_000 },
    [_]i32{ 10_000, 60_000, 100_000 },
    [_]i32{ 500_000, 500_000, 500_000 },
};

pub fn scorePattern(info: LineInfo) i32 {
    const count = @min(info.count, 5);
    const openness_type = determineOpennessType(info.open_left, info.open_right);
    return SCORES[count][openness_type];
}

fn determineOpennessType(left_open: bool, right_open: bool) usize {
    if (left_open and right_open) {
        return 2;
    }
    if (left_open or right_open) {
        return 1;
    }
    return 0;
}

test "scanLine" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    board_mod.makeMove(&board, 10, 10, .me);
    board_mod.makeMove(&board, 10, 11, .me);
    board_mod.makeMove(&board, 10, 12, .me);

    const info = scanLine(&board, 10, 11, HORIZONTAL, .me);
    try std.testing.expectEqual(@as(usize, 3), info.count);
    try std.testing.expect(info.open_left and info.open_right);
}

test "pattern scoring" {
    const five = LineInfo{ .count = 5, .open_left = false, .open_right = false };
    try std.testing.expectEqual(@as(i32, 500_000), scorePattern(five));

    const open_four = LineInfo{ .count = 4, .open_left = true, .open_right = true };
    try std.testing.expectEqual(@as(i32, 100_000), scorePattern(open_four));

    const semi_four = LineInfo{ .count = 4, .open_left = true, .open_right = false };
    try std.testing.expectEqual(@as(i32, 60_000), scorePattern(semi_four));
}
