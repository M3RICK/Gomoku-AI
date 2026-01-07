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

const BOARD_MAX_SIZE = 20;
const TABLE_SIZE: usize = 1_000_000;
const ZOBRIST_SEED: u64 = 0xFEDCBA987654321;

const PLAYER_ME_INDEX: usize = 0;
const PLAYER_OPPONENT_INDEX: usize = 1;

var zobrist_random_numbers: [BOARD_MAX_SIZE][BOARD_MAX_SIZE][2]u64 = undefined;
var zobrist_initialized = false;

pub fn initZobrist() void {
    if (zobrist_initialized) {
        return;
    }

    generateRandomNumbersForZobrist();
    zobrist_initialized = true;
}

fn generateRandomNumbersForZobrist() void {
    var random_generator = std.Random.DefaultPrng.init(ZOBRIST_SEED);
    const random = random_generator.random();

    for (0..BOARD_MAX_SIZE) |x| {
        for (0..BOARD_MAX_SIZE) |y| {
            zobrist_random_numbers[x][y][PLAYER_ME_INDEX] = random.int(u64);
            zobrist_random_numbers[x][y][PLAYER_OPPONENT_INDEX] = random.int(u64);
        }
    }
}

pub fn computeHash(board: *const Board) u64 {
    var hash: u64 = 0;

    for (0..board.size) |x| {
        for (0..board.size) |y| {
            const cell = board_mod.getCell(board, x, y);

            if (cellIsOccupied(cell)) {
                const random_number = getZobristNumber(x, y, cell);
                hash = xorHash(hash, random_number);
            }
        }
    }

    return hash;
}

fn cellIsOccupied(cell: Cell) bool {
    return cell == .me or cell == .opponent;
}

fn getZobristNumber(x: usize, y: usize, player: Cell) u64 {
    const player_index = getPlayerIndex(player);
    return zobrist_random_numbers[x][y][player_index];
}

fn getPlayerIndex(player: Cell) usize {
    if (player == .me) {
        return PLAYER_ME_INDEX;
    } else {
        return PLAYER_OPPONENT_INDEX;
    }
}

fn xorHash(current_hash: u64, value: u64) u64 {
    return current_hash ^ value;
}

pub fn updateHash(current_hash: u64, x: usize, y: usize, player: Cell) u64 {
    const random_number = getZobristNumber(x, y, player);
    return xorHash(current_hash, random_number);
}

pub const TranspositionTable = struct {
    entries: []?TTEntry,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !TranspositionTable {
        const entries = try allocator.alloc(?TTEntry, TABLE_SIZE);

        clearAllEntries(entries);

        return TranspositionTable{
            .entries = entries,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TranspositionTable) void {
        self.allocator.free(self.entries);
    }

    pub fn store(
        self: *TranspositionTable,
        hash: u64,
        best_move: Move,
        score: i32,
        depth: i32,
        node_type: NodeType,
    ) void {
        const table_index = calculateTableIndex(hash);

        self.entries[table_index] = TTEntry{
            .hash = hash,
            .best_move = best_move,
            .score = score,
            .depth = depth,
            .node_type = node_type,
        };
    }

    pub fn probe(self: *const TranspositionTable, hash: u64) ?TTEntry {
        const table_index = calculateTableIndex(hash);
        const entry = self.entries[table_index];

        if (entry == null) {
            return null;
        }

        if (hashesMatch(entry.?.hash, hash)) {
            return entry;
        }

        return null;
    }

    pub fn clear(self: *TranspositionTable) void {
        clearAllEntries(self.entries);
    }
};

fn calculateTableIndex(hash: u64) usize {
    return hash % TABLE_SIZE;
}

fn hashesMatch(stored_hash: u64, query_hash: u64) bool {
    return stored_hash == query_hash;
}

fn clearAllEntries(entries: []?TTEntry) void {
    for (entries) |*entry| {
        entry.* = null;
    }
}

test "zobrist hashing" {
    initZobrist();
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    const hash_before_move = computeHash(&board);
    board_mod.makeMove(&board, 10, 10, .me);
    const hash_after_move = computeHash(&board);

    try std.testing.expect(hash_before_move != hash_after_move);
}

test "transposition table" {
    initZobrist();
    const allocator = std.testing.allocator;
    var table = try TranspositionTable.init(allocator);
    defer table.deinit();

    const hash: u64 = 12345;
    const move = Move.init(10, 10);
    table.store(hash, move, 1000, 5, .exact);

    const entry = table.probe(hash);
    try std.testing.expect(entry != null);
    try std.testing.expectEqual(@as(i32, 1000), entry.?.score);
}
