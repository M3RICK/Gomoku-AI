const std = @import("std");
const move_mod = @import("../../game/move.zig");
const Move = move_mod.Move;

pub const Node = struct {
    move: Move,
    visits: usize,
    wins: f32,
    parent: ?*Node,
    children: std.ArrayList(*Node),
    allocator: std.mem.Allocator,
    is_fully_expanded: bool,
    available_moves: std.ArrayList(Move),

    pub fn init(allocator: std.mem.Allocator, move: Move, parent: ?*Node) !*Node {
        const node = try allocator.create(Node);

        node.* = Node{
            .move = move,
            .visits = 0,
            .wins = 0.0,
            .parent = parent,
            .children = std.ArrayList(*Node){},
            .allocator = allocator,
            .is_fully_expanded = false,
            .available_moves = std.ArrayList(Move){},
        };
        return node;
    }

    pub fn deinit(self: *Node) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit(self.allocator);
        self.available_moves.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn getWinRate(self: *const Node) f32 {
        if (self.visits == 0) {
            return 0.0;
        }
        const visits_f32: f32 = @floatFromInt(self.visits);
        return self.wins / visits_f32;
    }

    pub fn isVisited(self: *const Node) bool {
        return self.visits > 0;
    }

    pub fn isLeaf(self: *const Node) bool {
        return self.children.items.len == 0;
    }

    pub fn canExpand(self: *const Node) bool {
        if (self.is_fully_expanded) {
            return false;
        }
        return self.available_moves.items.len > 0;
    }

    pub fn getBestChild(self: *const Node) ?*Node {
        if (self.children.items.len == 0) {
            return null;
        }

        var best_child = self.children.items[0];
        var best_visits = best_child.visits;

        for (self.children.items[1..]) |child| {
            if (child.visits > best_visits) {
                best_visits = child.visits;
                best_child = child;
            }
        }

        return best_child;
    }

    pub fn addChild(self: *Node, move: Move) !*Node {
        const child = try Node.init(self.allocator, move, self);
        try self.children.append(self.allocator, child);
        return child;
    }

    pub fn setAvailableMoves(self: *Node, moves: []Move) !void {
        try self.available_moves.appendSlice(self.allocator, moves);
    }

    pub fn getNextMoveToExpand(self: *Node) ?Move {
        if (self.available_moves.items.len == 0) {
            self.is_fully_expanded = true;
            return null;
        }
        return self.available_moves.pop();
    }
};
