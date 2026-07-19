const std = @import("std");

const c = @cImport({
    @cInclude("basin.h");
});

pub const BasinConfig = struct {
    width: u32,
    height: u32,
    channels: u32,
};

pub fn init(cfg: BasinConfig) !void {
    var c_cfg = c.BasinConfig{
        .width = cfg.width,
        .height = cfg.height,
        .channels = cfg.channels,
    };
    const ret = c.basin_init(&c_cfg);
    std.debug.print("basin_init returned: {}\n", .{ret}); // ADD THIS
    if (ret != 0) {
        return error.InitFailed;
    }
}

pub fn deinit() void {
    c.basin_free();
}

pub fn poseidonHash(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const out = try allocator.alloc(u8, 16);
    errdefer allocator.free(out);
    const ret = c.basin_poseidon_hash(input.ptr, input.len, out.ptr); // CHECK THIS TOO
    std.debug.print("basin_poseidon_hash returned: {}\n", .{ret}); // ADD THIS
    if (ret != 0) {
        return error.HashFailed;
    }
    return out;
}

pub fn toHex(bytes: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const hex_chars = "0123456789abcdef";
    const out = try allocator.alloc(u8, bytes.len * 2);
    errdefer allocator.free(out);
    for (bytes, 0..) |b, i| {
        out[i * 2] = hex_chars[b >> 4];
        out[i * 2 + 1] = hex_chars[b & 0x0F];
    }
    return out;
}

pub fn parallelProcess(data: []const u8, threads: i32) !void {
    if (c.basin_parallel_process(data.ptr, data.len, threads) != 0) {
        return error.ParallelFailed;
    }
}
