const std = @import("std");
const parser = @import("parser.zig");
const writer = @import("writer.zig");
const types = @import("types.zig");
const errors = @import("errors.zig");

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

// Helpers

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

fn parseAndValidateMove(line: []const u8, size: usize) !types.Move {
    const move = parser.parseMove(line) catch {
        return error.InvalidMoveFormat;
    };
    if (move.x >= size or move.y >= size) {
        return error.MoveOutOfBounds;
    }
    return move;
}

fn getCenter(size: usize) usize {
    return size / 2;
}

fn recordMove(ctx: *Context, move: types.Move) !void {
    ctx.move_count += 1;
    try writer.sendMove(move);
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

    const center = getCenter(size);
    const move = types.Move{ .x = center, .y = center };
    try recordMove(ctx, move);
}

fn handleTurn(ctx: *Context, line: []const u8) !void {
    const size = getBoardSize(ctx) catch {
        try errors.sendBoardNotInitialized();
        return;
    };

    const opponent_move = parseAndValidateMove(line, size) catch |err| {
        if (err == error.InvalidMoveFormat) {
            try errors.sendInvalidMoveFormat();
        } else {
            try errors.sendMoveOutOfBounds();
        }
        return;
    };

    // Just go right until we have a brain
    const our_move = types.Move{
        .x = if (opponent_move.x + 1 < size) opponent_move.x + 1 else opponent_move.x,
        .y = opponent_move.y,
    };
    try recordMove(ctx, our_move);
}

fn handleBoard(ctx: *Context) !void {
    const size = getBoardSize(ctx) catch {
        try errors.sendBoardNotInitialized();
        return;
    };

    const center = getCenter(size);
    const move = types.Move{ .x = center, .y = center };
    try writer.sendMove(move);
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
