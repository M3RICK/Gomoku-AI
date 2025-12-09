const std = @import("std");
const writer = @import("writer.zig");

pub fn sendBoardNotInitialized() !void {
    try writer.sendError("Board not initialized");
}

pub fn sendInvalidBoardSize() !void {
    try writer.sendError("Board size MUST be 5-20");
}

pub fn sendInvalidMoveFormat() !void {
    try writer.sendError("Wrong move format");
}

pub fn sendMoveOutOfBounds() !void {
    try writer.sendError("Move is out of bounds dumdum");
}
