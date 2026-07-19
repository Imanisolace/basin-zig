const std = @import("std");

const c = @cImport({
    @cInclude("basin.h");
});

pub fn main()!void {
    const stdout = std.io.getStdOut().writer();

    var cfg = c.BasinConfig{
       .width = 512,
       .height = 512, 
       .channels = 3,
    };
    const init_res = c.basin_init(&cfg);
    if (init_res == 0) {} else {
        try stdout.print("Failed to init Basin\n",.{});
        return error.InitFailed;
    }
    defer c.basin_free();

    const input = "basin benchmark data";
    var output: [32]u8 = undefined;

    _ = c.basin_poseidon_hash(input.ptr, input.len, &output);

    const t1 = std.time.milliTimestamp();
    _ = c.basin_poseidon_hash(input.ptr, input.len, &output);
    const t2 = std.time.milliTimestamp();
    const single_ms = t2 - t1;

    const t3 = std.time.milliTimestamp();
    const ret = c.basin_parallel_process(input.ptr, input.len, 8);
    const t4 = std.time.milliTimestamp();
    const parallel_ms = t4 - t3;

    if (ret == 0) {} else {
        try stdout.print("Parallel process failed\n",.{});
        return error.ParallelFailed;
    }

    try stdout.print("=== Basin Benchmark ===\n",.{});
    try stdout.print("Input: {s}\n",.{input});
    try stdout.print("Single hash: {d}ms\n",.{single_ms});
    try stdout.print("Parallel 8 threads, 8000 hashes: {d}ms\n",.{parallel_ms});
    
    try stdout.print("Sample Hash: ",.{});
    for (output) |b| {
        try stdout.print("{x:0>2}",.{b});
    }
    try stdout.print("\n",.{});
    try stdout.print("Success!\n",.{});
}