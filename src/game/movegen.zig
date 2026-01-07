const std = @import("std");
const board_mod = @import("board.zig");
const move_mod = @import("move.zig");
const Board = board_mod.Board;
const Move = move_mod.Move;

pub const MoveGenerator = struct {
    allocator: std.mem.Allocator,
    moves: std.ArrayList(Move),
    visited: std.AutoHashMap(u64, void),

    pub fn init(allocator: std.mem.Allocator) MoveGenerator {
        return MoveGenerator{
            .allocator = allocator,
            .moves = std.ArrayList(Move){},
            .visited = std.AutoHashMap(u64, void).init(allocator),
        };
    }

    pub fn deinit(self: *MoveGenerator) void {
        self.moves.deinit(self.allocator);
        self.visited.deinit();
    }

    pub fn reset(self: *MoveGenerator) void {
        self.moves.clearRetainingCapacity();
        self.visited.clearRetainingCapacity();
    }

    pub fn generateAll(self: *MoveGenerator, board: *const Board) ![]Move {
        self.reset();

        for (0..board.size) |x| {
            for (0..board.size) |y| {
                if (board_mod.isEmpty(board, x, y)) {
                    try self.moves.append(self.allocator, Move.init(x, y));
                }
            }
        }

        return try self.moves.toOwnedSlice(self.allocator);
    }

    pub fn generateSmart(self: *MoveGenerator, board: *const Board, radius: usize) ![]Move {
        self.reset();

        if (board.move_count == 0) {
            return try self.generateCenterMove(board);
        }

        const adaptive_radius = calculateAdaptiveRadius(board, radius);
        try self.collectAllNeighbors(board, adaptive_radius);
        return try self.moves.toOwnedSlice(self.allocator);
    }

    fn generateCenterMove(self: *MoveGenerator, board: *const Board) ![]Move {
        const center = move_mod.getCenter(board);
        try self.moves.append(self.allocator, center);
        return try self.moves.toOwnedSlice(self.allocator);
    }

    fn collectAllNeighbors(self: *MoveGenerator, board: *const Board, radius: usize) !void {
        for (0..board.size) |x| {
            for (0..board.size) |y| {
                if (!board_mod.isEmpty(board, x, y)) {
                    try self.collectNeighborsOf(board, x, y, radius);
                }
            }
        }
    }

    fn collectNeighborsOf(self: *MoveGenerator, board: *const Board, x: usize, y: usize, radius: usize) !void {
        const start_x = if (x >= radius) x - radius else 0;
        const start_y = if (y >= radius) y - radius else 0;
        const end_x = @min(x + radius + 1, board.size);
        const end_y = @min(y + radius + 1, board.size);

        for (start_x..end_x) |nx| {
            for (start_y..end_y) |ny| {
                try self.tryAddMove(board, nx, ny);
            }
        }
    }

    fn tryAddMove(self: *MoveGenerator, board: *const Board, x: usize, y: usize) !void {
        if (!board_mod.isEmpty(board, x, y)) {
            return;
        }

        const hash = hashPosition(x, y);
        if (self.visited.contains(hash)) {
            return;
        }

        try self.visited.put(hash, {});
        try self.moves.append(self.allocator, Move.init(x, y));
    }
};

fn calculateAdaptiveRadius(board: *const Board, base_radius: usize) usize {
    const move_count = board.move_count;

    if (move_count <= 6) {
        return 1;
    }

    if (move_count <= 20) {
        return base_radius;
    }

    if (move_count <= 40) {
        return base_radius + 1;
    }

    return base_radius + 1;
}

fn hashPosition(x: usize, y: usize) u64 {
    return (@as(u64, x) << 32) | @as(u64, y);
}

test "smarter move generation" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    var gen = MoveGenerator.init(allocator);
    defer gen.deinit();

    const moves = try gen.generateSmart(&board, 1);
    defer allocator.free(moves);

    try std.testing.expectEqual(@as(usize, 1), moves.len);
}
