const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const threat = @import("../evaluation/threat.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

const WIN_MOVE_SCORE: i32 = 9_800_000;
const BLOCK_WIN_SCORE: i32 = 8_900_000;
const KILLER_MOVE_SCORE: i32 = 8_700_000;
const CREATE_FORK_SCORE: i32 = 8_500_000;
const BLOCK_FORK_SCORE: i32 = 8_400_000;
const CENTER_BONUS_PER_UNIT: i32 = 95;

pub fn orderMoves(board: *Board, moves: []Move, player: Cell, allocator: std.mem.Allocator) !void {
    return orderMovesWithKillers(board, moves, player, allocator, null, 0);
}

pub fn orderMovesWithKillers(board: *Board, moves: []Move, player: Cell, allocator: std.mem.Allocator, killers: ?[2]?Move, depth: i32) !void {
    const move_scores = try allocator.alloc(i32, moves.len);
    defer allocator.free(move_scores);

    for (moves, 0..) |current_move, index| {
        move_scores[index] = scoreMoveWithKillers(board, current_move, player, killers);
    }

    sortMovesByScore(moves, move_scores);
    _ = depth;
}

fn scoreMoveWithKillers(board: *Board, move: Move, player: Cell, killers: ?[2]?Move) i32 {
    var total_score: i32 = 0;

    if (threat.isWinningMove(board, move, player)) {
        total_score = WIN_MOVE_SCORE;
        total_score += @divTrunc(centerProximity(board, move), 1000);
        return total_score;
    }

    if (threat.isBlockingWin(board, move, player)) {
        total_score = BLOCK_WIN_SCORE;
        total_score += @divTrunc(threat.scoreThreatCreation(board, move, player), 100);
        total_score += centerProximity(board, move);
        return total_score;
    }

    if (killers) |killer_moves| {
        for (killer_moves) |maybe_killer| {
            if (maybe_killer) |killer| {
                if (killer.x == move.x and killer.y == move.y) {
                    return KILLER_MOVE_SCORE + centerProximity(board, move);
                }
            }
        }
    }

    return scoreMoveRegular(board, move, player);
}

pub fn scoreMove(board: *Board, move: Move, player: Cell) i32 {
    return scoreMoveWithKillers(board, move, player, null);
}

fn scoreMoveRegular(board: *Board, move: Move, player: Cell) i32 {
    var total_score: i32 = 0;

    if (threat.createsSemiOpenFour(board, move, player)) {
        total_score = CREATE_FORK_SCORE + 100_000;
        total_score += centerProximity(board, move);
        return total_score;
    }

    const opponent = board_mod.getOpponent(player);
    if (threat.createsSemiOpenFour(board, move, opponent)) {
        total_score = BLOCK_FORK_SCORE + 100_000;
        total_score += centerProximity(board, move);
        return total_score;
    }

    total_score += scoreForkMoves(board, move, player);
    total_score += threat.scoreThreatCreation(board, move, player);
    total_score += threat.scoreThreatBlocking(board, move, player);
    total_score += centerProximity(board, move);

    return total_score;
}

fn scoreForkMoves(board: *Board, move: Move, player: Cell) i32 {
    var fork_score: i32 = 0;

    if (threat.detectFork(board, move, player)) {
        fork_score += CREATE_FORK_SCORE;
    }

    const opponent = board_mod.getOpponent(player);
    if (threat.detectFork(board, move, opponent)) {
        fork_score += BLOCK_FORK_SCORE;
    }

    return fork_score;
}

fn centerProximity(board: *const Board, move: Move) i32 {
    const center = board.size / 2;

    const horizontal_distance = calculateDistance(move.x, center);
    const vertical_distance = calculateDistance(move.y, center);

    const total_distance = horizontal_distance + vertical_distance;
    const max_distance = board.size;
    const closeness = max_distance - total_distance;
    const bonus = (closeness * CENTER_BONUS_PER_UNIT) / max_distance;

    return @intCast(bonus);
}

fn calculateDistance(position: usize, center: usize) usize {
    if (position > center) {
        return position - center;
    } else {
        return center - position;
    }
}

fn sortMovesByScore(moves: []Move, scores: []i32) void {
    var i: usize = 1;
    while (i < moves.len) : (i += 1) {
        insertMoveInSortedPosition(moves, scores, i);
    }
}

fn insertMoveInSortedPosition(moves: []Move, scores: []i32, position: usize) void {
    var current_position = position;

    while (current_position > 0) {
        const previous_position = current_position - 1;
        const should_swap = scores[current_position] > scores[previous_position];

        if (!should_swap) {
            break;
        }

        swapMoves(moves, current_position, previous_position);
        swapScores(scores, current_position, previous_position);
        current_position = previous_position;
    }
}

fn swapMoves(moves: []Move, index1: usize, index2: usize) void {
    const temp = moves[index1];
    moves[index1] = moves[index2];
    moves[index2] = temp;
}

fn swapScores(scores: []i32, index1: usize, index2: usize) void {
    const temp = scores[index1];
    scores[index1] = scores[index2];
    scores[index2] = temp;
}

test "move ordering" {
    const allocator = std.testing.allocator;
    var board = try board_mod.init(allocator, 20);
    board_mod.deinit(&board);

    board_mod.makeMove(&board, 10, 10, .me);
    board_mod.makeMove(&board, 10, 11, .me);
    board_mod.makeMove(&board, 10, 12, .me);
    board_mod.makeMove(&board, 10, 13, .me);

    var moves = [_]Move{
        Move.init(5, 5),
        Move.init(10, 14),
        Move.init(7, 7),
    };

    try orderMoves(&board, &moves, .me, allocator);
    try std.testing.expectEqual(@as(usize, 10), moves[0].x);
}
