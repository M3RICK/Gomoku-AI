const std = @import("std");

pub const Command = enum {
    start, // START [size] - Initialize board
    begin, // BEGIN - We play first
    turn, // TURN [X],[Y] - Opponent played
    board, // BOARD - Load board position
    info, // INFO [key] [value] - Configuration
    end, // END - Terminate program
    unknown, // self explanatory
};

pub const Move = struct {
    x: usize,
    y: usize,
};

pub const Player = enum(u8) {
    empty = 0,
    me = 1,
    enemy = 2,
};

// Tests

test "Move creation" {
    const move = Move{ .x = 10, .y = 10 };

    try std.testing.expectEqual(move.x, 10);
    try std.testing.expectEqual(move.y, 10);
}

test "Player values" {
    try std.testing.expectEqual(@intFromEnum(Player.empty), 0);
    try std.testing.expectEqual(@intFromEnum(Player.me), 1);
    try std.testing.expectEqual(@intFromEnum(Player.enemy), 2);
}
