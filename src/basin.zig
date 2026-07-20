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

pub fn init(cfg: BasinConfig)!void {
    if (cfg.width == 0 or cfg.height == 0 or cfg.channels == 0) {
        return BasinError.InvalidConfig;
    }

    var c_cfg = c.BasinConfig{
       .width = cfg.width,
       .height = cfg.height,
       .channels = cfg.channels,
    };

    if (c.basin_init(&c_cfg)!= 0) {
        return BasinError.InitFailed;
    }
}

pub fn deinit() void {
    c.basin_free();
}

pub fn poseidonHash(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    if (input.len == 0) {
        return BasinError.EmptyInput;
    }

    const out = try allocator.alloc(u8, 32); // C writes 32 bytes
    errdefer allocator.free(out);

    if (c.basin_poseidon_hash(input.ptr, input.len, out.ptr)!= 0) {
        return BasinError.HashFailed;
    }

    return out;
}

pub fn toHex(bytes: []const u8, allocator: std.mem.Allocator)![]u8 {
    const hex_chars = "0123456789abcdef";
    const out = try allocator.alloc(u8, bytes.len * 2);
    errdefer allocator.free(out);

    for (bytes, 0..) |b, i| {
        out[i * 2] = hex_chars[b >> 4];
        out[i * 2 + 1] = hex_chars[b & 0x0F];
    }
    return out;
}

pub fn parallelProcess(data: []const u8, threads: i32)!void {
    if (data.len == 0) return BasinError.EmptyInput;
    if (threads <= 0) return BasinError.InvalidConfig;

    if (c.basin_parallel_process(data.ptr, data.len, threads)!= 0) {
        return BasinError.ParallelFailed;
    }
}

// === REAL STREAMING API - backed by C ===
pub const Hasher = struct {
    c_hasher: c.basin_hasher_t,

    pub fn init()!Hasher {
        var h: Hasher = undefined;
        if (c.basin_hasher_init(&h.c_hasher)!= 0) return BasinError.InitFailed;
        return h;
    }

    pub fn update(self: *Hasher, data: []const u8)!void {
        if (c.basin_hasher_update(&self.c_hasher, data.ptr, data.len)!= 0) {
            return BasinError.HashFailed;
        }
    }

    pub fn final(self: *Hasher, out: *[32]u8)!void {
        if (c.basin_hasher_final(&self.c_hasher, &out[0])!= 0) {
            return BasinError.HashFailed;
        }
    }

    pub fn deinit(self: *Hasher) void {
        _ = self; // C hasher has no heap, nothing to free
    }
};