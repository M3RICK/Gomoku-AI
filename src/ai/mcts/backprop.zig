const std = @import("std");
const Node = @import("node.zig").Node;
const simulation = @import("simulation.zig");

pub fn backpropagate(leaf: *Node, result: simulation.SimulationResult) void {
    const win_value = simulation.getWinValue(result);

    var current: ?*Node = leaf;
    var is_player_turn = true;

    while (current != null) {
        updateNodeStatistics(current.?, win_value, is_player_turn);

        current = current.?.parent;
        is_player_turn = !is_player_turn;
    }
}

fn updateNodeStatistics(node: *Node, win_value: f32, is_player_turn: bool) void {
    node.visits += 1;

    const value_to_add = calculateValueToAdd(win_value, is_player_turn);
    node.wins += value_to_add;
}

fn calculateValueToAdd(win_value: f32, is_player_turn: bool) f32 {
    if (is_player_turn) {
        return win_value;
    }

    return 1.0 - win_value;
}

pub fn updateNode(node: *Node, win_value: f32) void {
    node.visits += 1;
    node.wins += win_value;
}

pub fn getAverageValue(node: *const Node) f32 {
    if (node.visits == 0) {
        return 0.0;
    }
    const visits_f32: f32 = @floatFromInt(node.visits);
    return node.wins / visits_f32;
}

pub fn printNodeStats(node: *const Node) void {
    const win_rate = node.getWinRate();
    std.debug.print("Node stats: visits={d}, wins={d:.2}, win_rate={d:.2}%\n", .{
        node.visits,
        node.wins,
        win_rate * 100.0,
    });
}
