const std = @import("std");
const c = @cImport(@cInclude("basin.h"));

test "basin_init works" {
    var cfg = c.BasinConfig{.width = 512,.height = 512,.channels = 3 };
    try std.testing.expect(c.basin_init(&cfg) == 0);
    c.basin_free();
}

test "basin_poseidon_hash works" {
    const input = "test";
    var output: [32]u8 = undefined;
    try std.testing.expect(c.basin_poseidon_hash(input.ptr, input.len, &output) == 0);
}

test "basin_parallel_process works" {
    const data = [_]u8{1} ** 100;
    try std.testing.expect(c.basin_parallel_process(&data, data.len, 2) == 0);
}