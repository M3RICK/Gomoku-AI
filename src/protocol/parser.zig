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
        'A' => {
            if (std.mem.startsWith(u8, line, "ABOUT"))
                return .about;
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

pub fn parseMove(line: []const u8) !types.Coordinates {
    const space_pos = std.mem.indexOf(u8, line, " ") orelse return error.InvalidFormat;
    const coordinates = line[space_pos + 1 ..];

    const comma_pos = std.mem.indexOf(u8, coordinates, ",") orelse return error.InvalidFormat;

    const x_str = coordinates[0..comma_pos];
    const y_str = coordinates[comma_pos + 1 ..];

    const x = try std.fmt.parseInt(usize, x_str, 10);
    const y = try std.fmt.parseInt(usize, y_str, 10);

    return types.Coordinates{ .x = x, .y = y };
}

pub const BoardMove = struct {
    x: usize,
    y: usize,
    player: u8,
};

pub fn parseBoardMove(line: []const u8) !BoardMove {
    var iter = std.mem.splitScalar(u8, line, ',');

    const x_str = iter.next() orelse return error.InvalidFormat;
    const y_str = iter.next() orelse return error.InvalidFormat;
    const player_str = iter.next() orelse return error.InvalidFormat;

    const x = try std.fmt.parseInt(usize, x_str, 10);
    const y = try std.fmt.parseInt(usize, y_str, 10);
    const player = try std.fmt.parseInt(u8, player_str, 10);

    if (player != 1 and player != 2) {
        return error.InvalidPlayer;
    }

    return BoardMove{
        .x = x,
        .y = y,
        .player = player,
    };
}

pub const InfoKey = enum {
    timeout_turn,
    timeout_match,
    time_left,
    max_memory,
    game_type,
    rule,
    folder,
    evaluate,
    unknown,
};

pub const InfoCommand = struct {
    key: InfoKey,
    value: []const u8,
};

pub fn parseInfo(line: []const u8) !InfoCommand {
    var iter = std.mem.splitScalar(u8, line, ' ');
    _ = iter.next(); // Skip "INFO"

    const key_str = iter.next() orelse return error.InvalidFormat;
    const value_str = iter.next() orelse return error.InvalidFormat;

    const key: InfoKey = if (std.mem.eql(u8, key_str, "timeout_turn"))
        .timeout_turn
    else if (std.mem.eql(u8, key_str, "timeout_match"))
        .timeout_match
    else if (std.mem.eql(u8, key_str, "time_left"))
        .time_left
    else if (std.mem.eql(u8, key_str, "max_memory"))
        .max_memory
    else if (std.mem.eql(u8, key_str, "game_type"))
        .game_type
    else if (std.mem.eql(u8, key_str, "rule"))
        .rule
    else if (std.mem.eql(u8, key_str, "folder"))
        .folder
    else if (std.mem.eql(u8, key_str, "evaluate"))
        .evaluate
    else
        .unknown;

    return InfoCommand{
        .key = key,
        .value = value_str,
    };
}

test "parse commands" {
    try std.testing.expectEqual(types.Command.start, parseCommand("START 10"));
    try std.testing.expectEqual(types.Command.begin, parseCommand("BEGIN"));
    try std.testing.expectEqual(types.Command.turn, parseCommand("TURN 14,13"));
}

test "parse coordinates" {
    const move = try parseMove("TURN 16,17");
    try std.testing.expectEqual(@as(usize, 16), move.x);
    try std.testing.expectEqual(@as(usize, 17), move.y);
}
