const std = @import("std");

pub const BUFFER_MS: u32 = 200;
pub const MIN_RESERVE_MS: i64 = 300;

var clock: std.time.Timer = undefined;
var clock_ready: bool = false;

fn ensureTimerInit() void {
    if (!clock_ready) {
        clock = std.time.Timer.start() catch unreachable;
        clock_ready = true;
    }
}

fn getMillisNow() i64 {
    ensureTimerInit();
    const ns = clock.read();
    return @intCast(@divFloor(ns, 1_000_000));
}

pub fn getDeadline(limit_ms: u32) i64 {
    const now = getMillisNow();
    return now + limit_ms - BUFFER_MS;
}

pub fn isTimeUp(deadline: i64) bool {
    const now = getMillisNow();
    return now >= deadline;
}

pub fn shouldContinueToNextDepth(deadline: i64, depth: i32) bool {
    const left = getRemainingTime(deadline);
    if (left < MIN_RESERVE_MS) {
        return false;
    }

    const estimate = estimateTimeForNextDepth(depth);
    return left > estimate + MIN_RESERVE_MS;
}

fn getRemainingTime(deadline: i64) i64 {
    return @max(0, deadline - getMillisNow());
}

fn estimateTimeForNextDepth(d: i32) i64 {
    const base: i64 = 10;
    const growth: i64 = 3;
    var cost: i64 = base;

    var i: i32 = 0;
    while (i < d and i < 10) : (i += 1) {
        cost *= growth;
        if (cost > 10_000) break;
    }

    return cost;
}

// Tests

test "getDeadline calculates correctly" {
    const limit: u32 = 5000;
    const start = getMillisNow();
    const deadline = getDeadline(limit);

    const expected = start + limit - BUFFER_MS;
    const diff = @abs(deadline - expected);

    try std.testing.expect(diff < 10);
}

test "isTimeUp detects timeout" {
    const past_deadline: i64 = getMillisNow() - 1000;
    try std.testing.expect(isTimeUp(past_deadline));
}

test "isTimeUp allows when time remains" {
    const future_deadline: i64 = getMillisNow() + 10000;
    try std.testing.expect(!isTimeUp(future_deadline));
}
