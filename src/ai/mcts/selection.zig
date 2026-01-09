const std = @import("std");
const Node = @import("node.zig").Node;

const UCB1_CONSTANT: f32 = 1.41;

pub fn selectBestChild(parent: *Node) ?*Node {
    if (parent.children.items.len == 0) {
        return null;
    }

    var best_child = parent.children.items[0];
    var best_score = calculateUCB1(best_child, parent.visits);

    for (parent.children.items[1..]) |child| {
        const score = calculateUCB1(child, parent.visits);

        if (score > best_score) {
            best_score = score;
            best_child = child;
        }
    }

    return best_child;
}

fn calculateUCB1(node: *const Node, parent_visits: usize) f32 {
    if (node.visits == 0) {
        return std.math.inf(f32);
    }

    const exploitation = node.getWinRate();
    const exploration = calculateExplorationBonus(node.visits, parent_visits);

    return exploitation + exploration;
}

fn calculateExplorationBonus(node_visits: usize, parent_visits: usize) f32 {
    const parent_visits_f: f32 = @floatFromInt(parent_visits);
    const node_visits_f: f32 = @floatFromInt(node_visits);

    const log_parent = @log(parent_visits_f);
    const ratio = log_parent / node_visits_f;
    const sqrt_value = @sqrt(ratio);

    return UCB1_CONSTANT * sqrt_value;
}

pub fn selectNodeToExpand(root: *Node) *Node {
    var current = root;

    while (!current.isLeaf()) {
        if (current.canExpand()) {
            return current;
        }

        const selected = selectBestChild(current);
        if (selected == null) {
            return current;
        }
        current = selected.?;
    }

    return current;
}

pub fn isPromising(node: *const Node, threshold: f32) bool {
    if (node.visits == 0) {
        return true;
    }

    const win_rate = node.getWinRate();
    return win_rate >= threshold;
}
