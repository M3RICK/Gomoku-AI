const std = @import("std");
const board_mod = @import("../../game/board.zig");
const move_mod = @import("../../game/move.zig");
const movegen = @import("../../game/movegen.zig");
const timer = @import("../search/timer.zig");
const Node = @import("node.zig").Node;
const selection = @import("selection.zig");
const simulation = @import("simulation.zig");
const backprop = @import("backprop.zig");
const Board = board_mod.Board;
const Cell = board_mod.Cell;
const Move = move_mod.Move;

const MIN_ITERATIONS = 100;

pub fn findBestMove(
    board: *Board,
    player: Cell,
    time_limit_ms: u32,
    allocator: std.mem.Allocator,
) !Move {
    const deadline = timer.getDeadline(time_limit_ms);

    const root = try createRootNode(board, allocator);
    defer root.deinit();

    var iteration_count: usize = 0;

    while (shouldContinueSearch(deadline, iteration_count)) {
        try performOneIteration(board, root, player, allocator);
        iteration_count += 1;
    }

    const best_child = root.getBestChild();
    if (best_child == null) {
        return getFallbackMove(board, allocator);
    }

    return best_child.?.move;
}

fn createRootNode(
    board: *Board,
    allocator: std.mem.Allocator,
) !*Node {
    const dummy_move = Move.init(0, 0);
    const root = try Node.init(allocator, dummy_move, null);

    var gen = movegen.MoveGenerator.init(allocator);
    defer gen.deinit();

    const moves = try gen.generateSmart(board, 2);
    defer allocator.free(moves);

    try root.setAvailableMoves(moves);

    return root;
}

fn shouldContinueSearch(deadline: i64, iteration_count: usize) bool {
    if (iteration_count < MIN_ITERATIONS) {
        return true;
    }

    return !timer.isTimeUp(deadline);
}

fn performOneIteration(
    board: *Board,
    root: *Node,
    player: Cell,
    allocator: std.mem.Allocator,
) !void {
    const node_to_expand = selection.selectNodeToExpand(root);

    const new_node = try expandNode(board, node_to_expand, allocator);
    if (new_node == null) {
        return;
    }

    const result = try runSimulation(board, new_node.?, player, allocator);

    backprop.backpropagate(new_node.?, result);
}

fn expandNode(
    board: *Board,
    node: *Node,
    allocator: std.mem.Allocator,
) !?*Node {
    if (!node.canExpand()) {
        if (node.children.items.len == 0) {
            var gen = movegen.MoveGenerator.init(allocator);
            defer gen.deinit();

            const moves = try gen.generateSmart(board, 2);
            defer allocator.free(moves);

            try node.setAvailableMoves(moves);

            if (!node.canExpand()) {
                return null;
            }
        } else {
            return null;
        }
    }

    const move = node.getNextMoveToExpand();
    if (move == null) {
        return null;
    }

    const child = try node.addChild(move.?);
    return child;
}

fn runSimulation(
    board: *Board,
    node: *Node,
    original_player: Cell,
    allocator: std.mem.Allocator,
) !simulation.SimulationResult {
    const moves_to_apply = try collectMovesToNode(node, allocator);
    defer allocator.free(moves_to_apply);

    var current_player = original_player;

    for (moves_to_apply) |m| {
        board_mod.makeMove(board, m.x, m.y, current_player);
        current_player = board_mod.getOpponent(current_player);
    }

    const result = try simulation.simulate(board, current_player, allocator);

    var i = moves_to_apply.len;
    while (i > 0) {
        i -= 1;
        const m = moves_to_apply[i];
        board_mod.undoMove(board, m.x, m.y);
    }

    return result;
}

fn collectMovesToNode(node: *Node, allocator: std.mem.Allocator) ![]Move {
    var moves = std.ArrayList(Move){};
    errdefer moves.deinit(allocator);

    var current: ?*Node = node;

    while (current != null and current.?.parent != null) {
        try moves.append(allocator, current.?.move);
        current = current.?.parent;
    }

    std.mem.reverse(Move, moves.items);

    return moves.toOwnedSlice(allocator);
}

fn getFallbackMove(board: *const Board, allocator: std.mem.Allocator) !Move {
    var gen = movegen.MoveGenerator.init(allocator);
    defer gen.deinit();

    const moves = try gen.generateSmart(board, 2);
    defer allocator.free(moves);

    if (moves.len > 0) {
        return moves[0];
    }

    const center = board.size / 2;
    return Move.init(center, center);
}
