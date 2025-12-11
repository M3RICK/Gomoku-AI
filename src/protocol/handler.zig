const std = @import("std");
const parser = @import("parser.zig");
const writer = @import("writer.zig");
const types = @import("types.zig");
const errors = @import("errors.zig");
const move_mod = @import("../game/move.zig");
const Move = move_mod.Move;

pub const Context = struct {
    allocator: std.mem.Allocator,
    board_size: ?usize = null,
    move_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Context {
        return Context{
            .allocator = allocator,
        };
    }
};

pub fn handleCommand(ctx: *Context, command: types.Command, line: []const u8) !bool {
    switch (command) {
        .start => try handleStart(ctx, line),
        .begin => try handleBegin(ctx),
        .turn => try handleTurn(ctx, line),
        .board => try handleBoard(ctx),
        .info => handleInfo(line),
        .end => return false,
        .unknown => try writer.sendError("Unknown command"),
    }
    return true;
}

fn getBoardSize(ctx: *Context) !usize {
    return ctx.board_size orelse error.BoardNotInitialized;
}

fn isValidBoardSize(size: usize) bool {
    return size >= 5 and size <= 20;
}

fn parseAndValidateBoardSize(line: []const u8) !usize {
    const size = parser.parseBoardSize(line) catch {
        return error.InvalidBoardSize;
    };
    if (!isValidBoardSize(size)) {
        return error.InvalidBoardSize;
    }
    return size;
}

fn parseAndValidateMove(line: []const u8, size: usize) !types.Coordinates {
    const coords = parser.parseMove(line) catch {
        return error.InvalidMoveFormat;
    };
    if (coords.x >= size or coords.y >= size) {
        return error.MoveOutOfBounds;
    }
    return coords;
}

fn recordMove(ctx: *Context, move: Move) !void {
    ctx.move_count += 1;
    const coords = types.Coordinates{ .x = move.x, .y = move.y };
    try writer.sendMove(coords);
}

fn handleStart(ctx: *Context, line: []const u8) !void {
    const size = parseAndValidateBoardSize(line) catch {
        try errors.sendInvalidBoardSize();
        return;
    };

    ctx.board_size = size;
    ctx.move_count = 0;
    try writer.sendOk();
}

fn handleBegin(ctx: *Context) !void {
    const size = getBoardSize(ctx) catch {
        try errors.sendBoardNotInitialized();
        return;
    };

    const center = size / 2;
    const move = Move.init(center, center);
    try recordMove(ctx, move);
}

fn handleTurn(ctx: *Context, line: []const u8) !void {
    const size = getBoardSize(ctx) catch {
        try errors.sendBoardNotInitialized();
        return;
    };

    const opponent_coords = parseAndValidateMove(line, size) catch |err| {
        if (err == error.InvalidMoveFormat) {
            try errors.sendInvalidMoveFormat();
        } else {
            try errors.sendMoveOutOfBounds();
        }
        return;
    };

    // Just go right until we have a brain
    const our_move = Move.init(
        if (opponent_coords.x + 1 < size) opponent_coords.x + 1 else opponent_coords.x,
        opponent_coords.y,
    );
    try recordMove(ctx, our_move);
}

fn handleBoard(ctx: *Context) !void {
    const size = getBoardSize(ctx) catch {
        try errors.sendBoardNotInitialized();
        return;
    };

    const center = size / 2;
    const coords = types.Coordinates{ .x = center, .y = center };
    try writer.sendMove(coords);
}

fn handleInfo(line: []const u8) void {
    // todo
    _ = line;
}

// Tests
test "context initialization" {
    const allocator = std.testing.allocator;
    const ctx = Context.init(allocator);

    try std.testing.expectEqual(@as(?usize, null), ctx.board_size);
    try std.testing.expectEqual(@as(usize, 0), ctx.move_count);
}

test "handle start command" {
    const allocator = std.testing.allocator;
    var ctx = Context.init(allocator);

    try handleStart(&ctx, "START 15");
    try std.testing.expectEqual(@as(?usize, 15), ctx.board_size);
}
