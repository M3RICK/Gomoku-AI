const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const pattern = @import("pattern.zig");
const direction = @import("../../game/direction.zig");
const rules = @import("../../game/rules.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

pub fn isWinningMove(board: *Board, move: Move, player: Cell) bool {
    board_mod.makeMove(board, move.x, move.y, player);
    const wins = rules.checkWin(board, move.x, move.y);
    board_mod.undoMove(board, move.x, move.y);
    return wins;
}

pub fn isBlockingWin(board: *Board, move: Move, player: Cell) bool {
    const opponent = board_mod.getOpponent(player);
    return isWinningMove(board, move, opponent);
}

pub fn createsOpenFour(board: *Board, move: Move, player: Cell) bool {
    board_mod.makeMove(board, move.x, move.y, player);
    const has_open_four = hasOpenFour(board, move.x, move.y);
    board_mod.undoMove(board, move.x, move.y);
    return has_open_four;
}

fn hasOpenFour(board: *const Board, x: usize, y: usize) bool {
    const directions = [_]direction.Direction{
        pattern.HORIZONTAL,
        pattern.VERTICAL,
        pattern.DIAGONAL,
        pattern.ANTI_DIAGONAL,
    };
    for (directions) |d| {
        const info = pattern.scanLine(board, x, y, d, board_mod.getCell(board, x, y));
        if (info.count == 4 and info.open_left and info.open_right) {
            return true;
        }
    }
    return false;
}

pub fn scoreThreatCreation(board: *Board, move: Move, player: Cell) i32 {
    board_mod.makeMove(board, move.x, move.y, player);
    const score = evaluateThreats(board, move.x, move.y);
    board_mod.undoMove(board, move.x, move.y);
    return score;
}

pub fn scoreThreatBlocking(board: *Board, move: Move, player: Cell) i32 {
    const opponent = board_mod.getOpponent(player);
    board_mod.makeMove(board, move.x, move.y, opponent);
    const score = evaluateThreats(board, move.x, move.y);
    board_mod.undoMove(board, move.x, move.y);
    return @divTrunc(score, 2);
}

fn evaluateThreats(board: *const Board, x: usize, y: usize) i32 {
    var total: i32 = 0;
    const directions = [_]direction.Direction{
        pattern.HORIZONTAL,
        pattern.VERTICAL,
        pattern.DIAGONAL,
        pattern.ANTI_DIAGONAL,
    };
    for (directions) |d| {
        const info = pattern.scanLine(board, x, y, d, board_mod.getCell(board, x, y));
        total += scoreThreatPattern(info);
    }
    return total;
}

fn scoreThreatPattern(info: pattern.LineInfo) i32 {
    if (info.count == 4) {
        const both_open = info.open_left and info.open_right;
        const one_open = info.open_left or info.open_right;
        if (both_open) {
            return 950_000;
        }
        if (one_open) {
            return 480_000;
        }
    }

    if (info.count == 3) {
        if (info.open_left and info.open_right) {
            return 95_000;
        }
    }

    return 0;
}

pub fn detectFork(board: *Board, move: Move, player: Cell) bool {
    board_mod.makeMove(board, move.x, move.y, player);
    const threats = countDangerousThreats(board, move.x, move.y);
    board_mod.undoMove(board, move.x, move.y);
    return threats >= 2;
}

fn countDangerousThreats(board: *const Board, x: usize, y: usize) usize {
    var count: usize = 0;
    const directions = [_]direction.Direction{
        pattern.HORIZONTAL,
        pattern.VERTICAL,
        pattern.DIAGONAL,
        pattern.ANTI_DIAGONAL,
    };

    for (directions) |dir| {
        const player = board_mod.getCell(board, x, y);
        const info = pattern.scanLine(board, x, y, dir, player);

        if (isDangerousThreat(info)) {
            count += 1;
        }
    }

    return count;
}

fn isDangerousThreat(info: pattern.LineInfo) bool {
    const is_open_four = info.count == 4 and (info.open_left or info.open_right);
    const is_open_three = info.count == 3 and info.open_left and info.open_right;
    return is_open_four or is_open_three;
}

test "threat detection" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    board_mod.deinit(&board);

    board_mod.makeMove(&board, 10, 10, .me);
    board_mod.makeMove(&board, 10, 11, .me);
    board_mod.makeMove(&board, 10, 12, .me);
    board_mod.makeMove(&board, 10, 13, .me);

    const move = Move.init(10, 14);
    try std.testing.expect(isWinningMove(&board, move, .me));
}
