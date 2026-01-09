const std = @import("std");
const board_mod = @import("../game/board.zig");
const move_mod = @import("../game/move.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

pub fn tryOpeningBook(board: *const Board) ?Move {
    const center = board.size / 2;

    if (board.move_count == 0) {
        return Move.init(center, center);
    }

    if (board.move_count == 1) {
        if (board_mod.getCell(board, center, center) == .opponent) {
            return Move.init(center + 1, center + 1);
        }
    }

    if (board.move_count == 2) {
        const center_cell = board_mod.getCell(board, center, center);

        if (center_cell == .me) {
            if (board_mod.getCell(board, center + 1, center) == .opponent) {
                return Move.init(center - 1, center);
            }
            if (board_mod.getCell(board, center, center + 1) == .opponent) {
                return Move.init(center, center - 1);
            }
            if (board_mod.getCell(board, center + 1, center + 1) == .opponent) {
                return Move.init(center - 1, center - 1);
            }
            if (board_mod.getCell(board, center - 1, center) == .opponent) {
                return Move.init(center + 1, center);
            }
            if (board_mod.getCell(board, center, center - 1) == .opponent) {
                return Move.init(center, center + 1);
            }
            if (board_mod.getCell(board, center - 1, center - 1) == .opponent) {
                return Move.init(center + 1, center + 1);
            }
        }
    }

    return null;
}
