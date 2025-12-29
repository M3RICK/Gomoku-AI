const std = @import("std");

// protocol modules
const reader = @import("protocol/reader.zig");
const parser = @import("protocol/parser.zig");
const handler = @import("protocol/handler.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var ctx = handler.Context.init(allocator);

    while (true) {
        const line = reader.readLineTrimmed(allocator) catch |err| {
            std.debug.print("Error reading: {}\n", .{err});
            continue;
        };

        const command = parser.parseCommand(line);

        const should_continue = handler.handleCommand(&ctx, command, line) catch |err| {
            std.debug.print("Handler error: {}\n", .{err});
            allocator.free(line);
            continue;
        };

        allocator.free(line);

        if (!should_continue) {
            ctx.deinit();
            _ = gpa.deinit();
            return;
        }
    }
}

