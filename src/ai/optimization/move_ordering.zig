const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const threat = @import("../evaluation/threat.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

const WIN_MOVE: i32 = 9_800_000;
const BLOCK_MOVE: i32 = 8_900_000;
const FORK_MOVE: i32 = 8_500_000;
const BLOCK_FORK: i32 = 8_400_000;
const CENTER_BONUS: i32 = 95;

pub fn orderMoves(board: *Board, moves: []Move, player: Cell) !void {
    const allocator = std.heap.page_allocator;
    const scores = try allocator.alloc(i32, moves.len);
    defer allocator.free(scores);

    for (moves, 0..) |m, i| {
        scores[i] = scoreMove(board, m, player);
    }

    sortMovesByScore(moves, scores);
}

pub fn scoreMove(board: *Board, move: Move, player: Cell) i32 {
    if (threat.isWinningMove(board, move, player)) return WIN_MOVE;
    if (threat.isBlockingWin(board, move, player)) return BLOCK_MOVE;

    var total: i32 = 0;
    total += scoreForkMoves(board, move, player);
    total += threat.scoreThreatCreation(board, move, player);
    total += threat.scoreThreatBlocking(board, move, player);
    total += centerProximity(board, move);

    return total;
}

fn scoreForkMoves(board: *Board, move: Move, player: Cell) i32 {
    var score: i32 = 0;

    if (threat.detectFork(board, move, player)) {
        score += FORK_MOVE;
    }

    const opponent = board_mod.getOpponent(player);
    if (threat.detectFork(board, move, opponent)) {
        score += BLOCK_FORK;
    }

    return score;
}

fn centerProximity(board: *const Board, move: Move) i32 {
    const mid = board.size / 2;
    const dx = if (move.x > mid) move.x - mid else mid - move.x;
    const dy = if (move.y > mid) move.y - mid else mid - move.y;
    const dist = dx + dy;

    const max_dist = board.size;
    const closeness = max_dist - dist;

    return @divTrunc(@as(i32, @intCast(closeness)) * CENTER_BONUS, @as(i32, @intCast(max_dist)));
}

fn sortMovesByScore(moves: []Move, scores: []i32) void {
    var i: usize = 0;
    while (i < moves.len) : (i += 1) {
        var j: usize = i;
        while (j > 0 and scores[j] > scores[j - 1]) : (j -= 1) {
            swap(Move, moves, j, j - 1);
            swap(i32, scores, j, j - 1);
        }
    }
}

fn swap(comptime T: type, arr: []T, i: usize, j: usize) void {
    const temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
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

    try orderMoves(&board, &moves, .me);
    try std.testing.expectEqual(@as(usize, 10), moves[0].x);
}
