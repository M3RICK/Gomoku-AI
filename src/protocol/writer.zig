const std = @import("std");
const types = @import("types.zig");

pub fn sendOk() !void {
    const stdout = std.fs.File.stdout();
    _ = try stdout.write("OK\n");
}

pub fn sendError(message: []const u8) !void {
    const stdout = std.fs.File.stdout();
    _ = try stdout.write("ERROR ");
    _ = try stdout.write(message);
    _ = try stdout.write("\n");
}

pub fn sendMove(coords: types.Coordinates) !void {
    const stdout = std.fs.File.stdout();

    var buffer: [64]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&buffer, "{d},{d}\n", .{ coords.x, coords.y });

    _ = try stdout.write(formatted);
}

pub fn sendDebug(message: []const u8) !void {
    const stdout = std.fs.File.stdout();
    _ = try stdout.write("MESSAGE ");
    _ = try stdout.write(message);
    _ = try stdout.write("\n");
}

