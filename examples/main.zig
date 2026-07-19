const std = @import("std");

// Link the C header
const c = @cImport({
    @cInclude("basin.h");
});

pub fn main()!void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Basin Example Running\n",.{});

    // 1. Init
    var cfg = c.BasinConfig{
       .width = 512,
       .height = 512,
       .channels = 3,
    };

    if (c.basin_init(&cfg)!= 0) {
        try stdout.print("Failed to init Basin\n",.{});
        return;
    }
    defer c.basin_free();

    try stdout.print("Basin initialized: {d}x{d}x{d}\n",.{cfg.width, cfg.height, cfg.channels});

    // 2. HASH DEMO - this is the payout part
    const input = "hello basin zig";
    var output: [32]u8 = undefined;

    const start = std.time.milliTimestamp();
    const ret = c.basin_poseidon_hash(input.ptr, input.len, &output);
    const end = std.time.milliTimestamp();

    if (ret!= 0) {
        try stdout.print("Hash failed\n",.{});
        return;
    }

    try stdout.print("Input: {s}\n",.{input});
    try stdout.print("Hash: ",.{});
    for (output) |b| {
        try stdout.print("{x:0>2}",.{b});
    }
    try stdout.print("\nTime: {d}ms\n",.{end - start});
    try stdout.print("Success!\n",.{});
}