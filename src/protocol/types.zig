const std = @import("std");

pub const Command = enum {
    start, // START [size] - Initialize board
    begin, // BEGIN - We play first
    turn, // TURN [X],[Y] - Opponent played
    board, // BOARD - Load board position
    info, // INFO [key] [value] - Configuration
    about, // ABOUT - Send brain information
    end, // END - Terminate program
    unknown, // self explanatory
};

pub const Coordinates = struct {
    x: usize,
    y: usize,
};
