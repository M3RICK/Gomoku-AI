const std = @import("std");
const board_mod = @import("../game/board.zig");
const move_mod = @import("../game/move.zig");
const minimax = @import("search/minimax.zig");
const transposition = @import("optimization/transposition.zig");
const opening_book = @import("opening_book.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    tt: transposition.TranspositionTable,

    pub fn init(allocator: std.mem.Allocator) !Engine {
        transposition.initZobrist();

        return Engine{
            .allocator = allocator,
            .tt = try transposition.TranspositionTable.init(allocator),
        };
    }

    pub fn deinit(self: *Engine) void {
        self.tt.deinit();
    }

    pub fn findBestMove(
        self: *Engine,
        board: *Board,
        time_limit_ms: u32,
        player: Cell,
    ) !Move {
        if (opening_book.tryOpeningBook(board)) |book_move| {
            return book_move;
        }

        return try minimax.findBestMove(
            board,
            time_limit_ms,
            &self.tt,
            player,
            self.allocator,
        );
    }
};

test "engine finds move" {
    const allocator = std.testing.allocator;
    var engine = try Engine.init(allocator);
    defer engine.deinit();

    var board = try board_mod.init(allocator, 20);
    defer board_mod.deinit(&board);

    board_mod.makeMove(&board, 10, 10, .opponent);
    const move = try engine.findBestMove(&board, 1000, .me);

    try std.testing.expect(board_mod.isEmpty(&board, move.x, move.y));
}
