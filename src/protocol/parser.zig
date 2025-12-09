const std = @import("std");
const types = @import("types.zig");

pub fn parseCommand(line: []const u8) types.Command {
    if (line.len == 0)
        return .unknown;
    switch (line[0]) {
        'S' => {
            if (std.mem.startsWith(u8, line, "START"))
                return .start;
        },
        'B' => {
            if (std.mem.startsWith(u8, line, "BEGIN"))
                return .begin;
            if (std.mem.startsWith(u8, line, "BOARD"))
                return .board;
        },
        'T' => {
            if (std.mem.startsWith(u8, line, "TURN"))
                return .turn;
        },
        'I' => {
            if (std.mem.startsWith(u8, line, "INFO"))
                return .info;
        },
        'E' => {
            if (std.mem.startsWith(u8, line, "END"))
                return .end;
        },
        else => {},
    }
    return .unknown;
}

pub fn parseBoardSize(line: []const u8) !usize {
    var iter = std.mem.splitScalar(u8, line, ' ');

    _ = iter.next(); // Skip "START"

    const size_str = iter.next() orelse return error.InvalidFormat;
    const size = try std.fmt.parseInt(usize, size_str, 10);

    return size;
}

pub fn parseMove(line: []const u8) !types.Move {
    const space_pos = std.mem.indexOf(u8, line, " ") orelse return error.InvalidFormat;
    const coordinates = line[space_pos + 1 ..];

    const comma_pos = std.mem.indexOf(u8, coordinates, ",") orelse return error.InvalidFormat;

    const x_str = coordinates[0..comma_pos];
    const y_str = coordinates[comma_pos + 1 ..];

    const x = try std.fmt.parseInt(usize, x_str, 10);
    const y = try std.fmt.parseInt(usize, y_str, 10);

    return types.Move{ .x = x, .y = y };
}

//TESTS

test "parse command types" {
    try std.testing.expectEqual(types.Command.start, parseCommand("START 10"));
    try std.testing.expectEqual(types.Command.begin, parseCommand("BEGIN"));
    try std.testing.expectEqual(types.Command.turn, parseCommand("TURN 14,13"));
    try std.testing.expectEqual(types.Command.board, parseCommand("BOARD"));
    try std.testing.expectEqual(types.Command.end, parseCommand("END"));
    try std.testing.expectEqual(types.Command.unknown, parseCommand("INVALID"));
}

test "parse board size" {
    const size = try parseBoardSize("START 10");
    try std.testing.expectEqual(@as(usize, 10), size);
}

test "parse move coordinates" {
    const move = try parseMove("TURN 16,17");
    try std.testing.expectEqual(@as(usize, 16), move.x);
    try std.testing.expectEqual(@as(usize, 17), move.y);
}

test "parse move with different coordinates" {
    const move = try parseMove("TURN 0,19");
    try std.testing.expectEqual(@as(usize, 0), move.x);
    try std.testing.expectEqual(@as(usize, 19), move.y);
}
