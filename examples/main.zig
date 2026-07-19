const std = @import("std");

// Link the C header
const c = @cImport({
    @cInclude("basin.h");
});

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("Basin Example Running\n", .{});

    var cfg = c.BasinConfig{
        .width = 512,
        .height = 512,
        .channels = 3,
    };

    if (c.basin_init(&cfg) != 0) {
        try stdout.print("Failed to init Basin\n", .{});
        return;
    }
    defer c.basin_free();

    try stdout.print("Basin initialized: {d}x{d}x{d}\n", .{cfg.width, cfg.height, cfg.channels});
    try stdout.print("Success!\n", .{});
}
