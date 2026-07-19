const std = @import("std");

// Import your C header
const c = @cImport({
    @cInclude("basin.h");
});

test "basin_init and basin_free" {
    var cfg = c.BasinConfig{
       .width = 512,
       .height = 512,
       .channels = 3,
    };
    
    // basin_init should return 0 on success
    const init_result = c.basin_init(&cfg);
    try std.testing.expect(init_result == 0);
    
    c.basin_free();
}

test "basin_poseidon_hash" {
    const input = "test input for poseidon";
    var output: [32]u8 = undefined; // change to [64] if your hash is 64 bytes
    
    const hash_result = c.basin_poseidon_hash(input.ptr, input.len, &output);
    try std.testing.expect(hash_result == 0);
    
    // make sure output isn't all zeros
    var all_zero = true;
    for (output) |byte| {
        if (byte!= 0) all_zero = false;
    }
    try std.testing.expect(!all_zero);
}

test "basin_parallel_process" {
    const data = [_]u8{ 1, 2, 3, 4, 5 } ** 100; // 500 bytes of data
    
    const result = c.basin_parallel_process(&data, data.len, 4);
    try std.testing.expect(result == 0);
}