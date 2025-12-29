const std = @import("std");

fn readByte(stdin: std.fs.File) !?u8 {
    var byte: [1]u8 = undefined;
    const bytes_read = try stdin.read(&byte);

    if (bytes_read == 0)
        return null;

    return byte[0];
}

fn collectLineBytes(allocator: std.mem.Allocator, stdin: std.fs.File) !std.ArrayList(u8) {
    var line: std.ArrayList(u8) = .empty;
    errdefer line.deinit(allocator);

    while (true) {
        const byte = try readByte(stdin) orelse break; // EOF

        if (byte == '\n')
            break;

        try line.append(allocator, byte);
    }

    return line;
}

pub fn readLine(allocator: std.mem.Allocator) ![]u8 {
    const stdin = std.fs.File.stdin();
    var line = try collectLineBytes(allocator, stdin);
    return line.toOwnedSlice(allocator);
}

pub fn readLineTrimmed(allocator: std.mem.Allocator) ![]u8 {
    const line = try readLine(allocator);
    defer allocator.free(line); // If dupe failes, madonne we are in a schlamassel

    const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
    return try allocator.dupe(u8, trimmed);
}

