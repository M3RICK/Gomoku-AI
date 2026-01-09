const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const pattern = @import("pattern.zig");
const advanced = @import("advanced_patterns.zig");
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

pub fn createsSemiOpenFour(board: *Board, move: Move, player: Cell) bool {
    board_mod.makeMove(board, move.x, move.y, player);
    const has_semi = advanced.createsSemiOpenFour(board, move.x, move.y, player);
    board_mod.undoMove(board, move.x, move.y);
    return has_semi;
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

    const broken_threes = advanced.countBrokenThrees(board, move.x, move.y, opponent);
    const broken_fours = advanced.countBrokenFours(board, move.x, move.y, opponent);
    const broken_fives = advanced.countBrokenFives(board, move.x, move.y, opponent);
    const threat_score = evaluateThreats(board, move.x, move.y);

    board_mod.undoMove(board, move.x, move.y);

    var block_score: i32 = 0;
    block_score += convertToScore(broken_threes, 60_000);
    block_score += convertToScore(broken_fours, 85_000);
    block_score += convertToScore(broken_fives, 95_000);
    block_score += threat_score;

    return block_score;
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
            return 550_000;
        }
    }

    if (info.count == 3) {
        if (info.open_left and info.open_right) {
            return 95_000;
        }
        if (info.open_left or info.open_right) {
            return 25_000;
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

pub fn countAllThreats(board: *Board, move: Move, player: Cell) usize {
    board_mod.makeMove(board, move.x, move.y, player);

    const regular_threats = countDangerousThreats(board, move.x, move.y);
    const broken_threes = advanced.countBrokenThrees(board, move.x, move.y, player);
    const broken_fours = advanced.countBrokenFours(board, move.x, move.y, player);
    const broken_fives = advanced.countBrokenFives(board, move.x, move.y, player);

    board_mod.undoMove(board, move.x, move.y);
    return regular_threats + broken_threes + (broken_fours * 2) + (broken_fives * 3);
}

pub fn calculateThreatQuality(board: *Board, move: Move, player: Cell) i32 {
    board_mod.makeMove(board, move.x, move.y, player);

    const regular = countDangerousThreats(board, move.x, move.y);
    const broken_threes = advanced.countBrokenThrees(board, move.x, move.y, player);
    const broken_fours = advanced.countBrokenFours(board, move.x, move.y, player);
    const broken_fives = advanced.countBrokenFives(board, move.x, move.y, player);
    const has_semi_four = advanced.createsSemiOpenFour(board, move.x, move.y, player);

    board_mod.undoMove(board, move.x, move.y);

    var quality: i32 = 0;

    if (has_semi_four) {
        quality += 500_000;
    }

    const regular_score = convertToScore(regular, 80_000);
    const broken_three_score = convertToScore(broken_threes, 40_000);
    const broken_four_score = convertToScore(broken_fours, 70_000);
    const broken_five_score = convertToScore(broken_fives, 90_000);

    quality += regular_score;
    quality += broken_three_score;
    quality += broken_four_score;
    quality += broken_five_score;

    return quality;
}

fn convertToScore(count: usize, multiplier: i32) i32 {
    const safe_count: i32 = @intCast(count);
    return safe_count * multiplier;
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
