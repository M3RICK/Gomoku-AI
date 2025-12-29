const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

pub const NodeType = enum {
    exact,
    lower_bound,
    upper_bound,
};

pub const TTEntry = struct {
    hash: u64,
    best_move: Move,
    score: i32,
    depth: i32,
    node_type: NodeType,
};

const BOARD_MAX = 20;
const TABLE_SIZE: usize = 1_500_000;

var hash_keys: [BOARD_MAX][BOARD_MAX][2]u64 = undefined;
var keys_ready = false;

pub fn initZobrist() void {
    if (keys_ready) return;

    var prng = std.Random.DefaultPrng.init(0xFEDCBA987654321);
    const rng = prng.random();

    for (0..BOARD_MAX) |x| {
        for (0..BOARD_MAX) |y| {
            hash_keys[x][y][0] = rng.int(u64);
            hash_keys[x][y][1] = rng.int(u64);
        }
    }

    keys_ready = true;
}

pub fn computeHash(board: *const Board) u64 {
    var h: u64 = 0;

    for (0..board.size) |x| {
        for (0..board.size) |y| {
            const cell = board_mod.getCell(board, x, y);
            if (cell == .me) {
                h ^= hash_keys[x][y][0];
            } else if (cell == .opponent) {
                h ^= hash_keys[x][y][1];
            }
        }
    }

    return h;
}

pub fn updateHash(h: u64, x: usize, y: usize, player: Cell) u64 {
    const idx: usize = if (player == .me) 0 else 1;
    return h ^ hash_keys[x][y][idx];
}

pub const TranspositionTable = struct {
    table: []?TTEntry,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !TranspositionTable {
        const tbl = try allocator.alloc(?TTEntry, TABLE_SIZE);
        for (tbl) |*slot| {
            slot.* = null;
        }

        return TranspositionTable{
            .table = tbl,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TranspositionTable) void {
        self.allocator.free(self.table);
    }

    pub fn store(
        self: *TranspositionTable,
        h: u64,
        best: Move,
        val: i32,
        d: i32,
        kind: NodeType,
    ) void {
        const idx = h % TABLE_SIZE;
        self.table[idx] = TTEntry{
            .hash = h,
            .best_move = best,
            .score = val,
            .depth = d,
            .node_type = kind,
        };
    }

    pub fn probe(self: *const TranspositionTable, h: u64) ?TTEntry {
        const idx = h % TABLE_SIZE;
        if (self.table[idx]) |entry| {
            if (entry.hash == h) return entry;
        }
        return null;
    }

    pub fn clear(self: *TranspositionTable) void {
        for (self.table) |*slot| {
            slot.* = null;
        }
    }
};

test "zobrist hashing" {
    initZobrist();
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    const hash1 = computeHash(&board);
    board_mod.makeMove(&board, 10, 10, .me);
    const hash2 = computeHash(&board);

    try std.testing.expect(hash1 != hash2);
}

test "transposition table" {
    initZobrist();
    const allocator = std.testing.allocator;
    var tt = try TranspositionTable.init(allocator);
    defer tt.deinit();

    const hash: u64 = 12345;
    const move = Move.init(10, 10);
    tt.store(hash, move, 1000, 5, .exact);

    const entry = tt.probe(hash);
    try std.testing.expect(entry != null);
    try std.testing.expectEqual(@as(i32, 1000), entry.?.score);
}
