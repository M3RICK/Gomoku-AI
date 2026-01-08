const std = @import("std");
const parser = @import("parser.zig");
const writer = @import("writer.zig");
const reader = @import("reader.zig");
const types = @import("types.zig");
const errors = @import("errors.zig");
const move_mod = @import("../game/move.zig");
const board_mod = @import("../game/board.zig");
const engine_mod = @import("../ai/engine.zig");
const Move = move_mod.Move;
const Board = board_mod.Board;
const Engine = engine_mod.Engine;

pub const Context = struct {
    allocator: std.mem.Allocator,
    board_size: ?usize = null,
    board: ?Board = null,
    engine: ?Engine = null,
    move_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Context {
        return Context{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Context) void {
        if (self.board) |*board| {
            board_mod.deinit(board);
        }
        if (self.engine) |*engine| {
            engine.deinit();
        }
    }
};

pub fn handleCommand(ctx: *Context, command: types.Command, line: []const u8) !bool {
    switch (command) {
        .start => try handleStart(ctx, line),
        .begin => try handleBegin(ctx),
        .turn => try handleTurn(ctx, line),
        .board => try handleBoard(ctx),
        .info => handleInfo(line),
        .about => try writer.sendAbout(),
        .end => return false,
        .unknown => try writer.sendError("Unknown command"),
    }
    return true;
}

fn handleStart(ctx: *Context, line: []const u8) !void {
    const sz = parser.parseBoardSize(line) catch {
        try errors.sendInvalidBoardSize();
        return;
    };

    if (sz < 5 or sz > 20) {
        try errors.sendInvalidBoardSize();
        return;
    }

    cleanupContext(ctx);

    ctx.board = try board_mod.init(ctx.allocator, sz);
    ctx.engine = try Engine.init(ctx.allocator);
    ctx.board_size = sz;
    ctx.move_count = 0;
    try writer.sendOk();
}

fn cleanupContext(ctx: *Context) void {
    if (ctx.board) |*b| board_mod.deinit(b);
    if (ctx.engine) |*e| e.deinit();
}

fn handleBegin(ctx: *Context) !void {
    var board = &(ctx.board orelse {
        try errors.sendBoardNotInitialized();
        return;
    });

    const mid = board.size / 2;
    board_mod.makeMove(board, mid, mid, .me);

    ctx.move_count += 1;
    try writer.sendMove(.{ .x = mid, .y = mid });
}

fn handleTurn(ctx: *Context, line: []const u8) !void {
    const board = &(ctx.board orelse {
        try errors.sendBoardNotInitialized();
        return;
    });
    const engine = &(ctx.engine orelse return error.EngineNotInitialized);

    const pos = parser.parseMove(line) catch {
        try errors.sendInvalidMoveFormat();
        return;
    };

    if (pos.x >= board.size or pos.y >= board.size) {
        try errors.sendMoveOutOfBounds();
        return;
    }

    board_mod.makeMove(board, pos.x, pos.y, .opponent);
    const my_move = try engine.findBestMove(board, 1000, .me);
    board_mod.makeMove(board, my_move.x, my_move.y, .me);

    ctx.move_count += 1;
    try writer.sendMove(.{ .x = my_move.x, .y = my_move.y });
}

fn handleBoard(ctx: *Context) !void {
    const board = &(ctx.board orelse {
        try errors.sendBoardNotInitialized();
        return;
    });
    const engine = &(ctx.engine orelse return error.EngineNotInitialized);

    board_mod.clear(board);
    try loadBoardMoves(ctx, board);

    const our_move = try engine.findBestMove(board, 1000, .me);
    board_mod.makeMove(board, our_move.x, our_move.y, .me);

    ctx.move_count += 1;
    try writer.sendMove(.{ .x = our_move.x, .y = our_move.y });
}

fn loadBoardMoves(ctx: *Context, board: *Board) !void {
    while (true) {
        const line = reader.readLineTrimmed(ctx.allocator) catch {
            try writer.sendError("Failed to read board moves");
            return;
        };
        defer ctx.allocator.free(line);

        if (std.mem.eql(u8, line, "DONE")) break;

        const mov = parser.parseBoardMove(line) catch {
            try writer.sendError("Invalid board move format");
            return;
        };

        if (mov.x >= board.size or mov.y >= board.size) {
            try errors.sendMoveOutOfBounds();
            return;
        }

        const p: board_mod.Cell = if (mov.player == 1) .me else .opponent;
        board_mod.makeMove(board, mov.x, mov.y, p);
    }
}

fn handleInfo(line: []const u8) void {
    // todo
    _ = line;
}

