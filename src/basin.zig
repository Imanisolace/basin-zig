const std = @import("std");
const c = @cImport({
    @cInclude("basin.h");
});

pub const BasinError = error{
    InitFailed,
    HashFailed,
    ParallelFailed,
    InvalidConfig,
    EmptyInput,
};

pub const BasinConfig = struct {
    width: u32,
    height: u32,
    channels: u32,
};

pub fn init(cfg: BasinConfig) !void {
    if (cfg.width == 0 or cfg.height == 0 or cfg.channels == 0) {
        return BasinError.InvalidConfig;
    }

    var c_cfg = c.BasinConfig{
        .width = cfg.width,
        .height = cfg.height,
        .channels = cfg.channels,
    };

    if (c.basin_init(&c_cfg) != 0) {
        return BasinError.InitFailed;
    }
}

pub fn deinit() void {
    c.basin_free();
}

pub fn poseidonHash(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (input.len == 0) {
        return BasinError.EmptyInput;
    }

    const out = try allocator.alloc(u8, 32); // C writes 32 bytes
    errdefer allocator.free(out);

    if (c.basin_poseidon_hash(input.ptr, input.len, out.ptr) != 0) {
        return BasinError.HashFailed;
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
    if (data.len == 0) return BasinError.EmptyInput;
    if (threads <= 0) return BasinError.InvalidConfig;

    if (c.basin_parallel_process(data.ptr, data.len, threads) != 0) {
        return BasinError.ParallelFailed;
    }
}