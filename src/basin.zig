const std = @import("std");

const c = @cImport({
    @cInclude("basin.h");
});

/// Public errors
pub const BasinError = error{
    InitFailed,
    HashFailed,
    ParallelFailed,
    InvalidConfig,
    EmptyInput,
};

/// Mirrors C BasinConfig
pub const BasinConfig = struct {
    width: u32,
    height: u32,
    channels: u32,
};

/// Initialize the C lib. Call once at startup
pub fn init(cfg: BasinConfig)!void {
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

/// Free the C lib. Call at shutdown
pub fn deinit() void {
    c.basin_free();
}

/// One-shot Poseidon hash. Returns 32 bytes.
/// Uses stack buffer for speed, then copies to heap
pub fn poseidonHash(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    if (input.len == 0) {
        return BasinError.EmptyInput;
    }

    var out_stack: [32]u8 = undefined; // stack: no leak, no errdefer
    const rc = c.basin_poseidon_hash(input.ptr, input.len, &out_stack);
    if (rc!= 0) {
        return BasinError.HashFailed;
    }

    // Copy to heap so caller owns it
    return try allocator.dupe(u8, &out_stack);
}

/// Convert bytes to lowercase hex string
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

/// Parallel processing wrapper
pub fn parallelProcess(data: []const u8, threads: i32)!void {
    if (data.len == 0) return BasinError.EmptyInput;
    if (threads <= 0) return BasinError.InvalidConfig;

    if (c.basin_parallel_process(data.ptr, data.len, threads) != 0) {
        return BasinError.ParallelFailed;
    }
}

/// Streaming Hasher backed by C basin_hasher_t
pub const Hasher = struct {
    c_hasher: c.basin_hasher_t,
    initialized: bool = false,

    /// Start a new hash
    pub fn init()!Hasher {
        var h: Hasher = undefined;
        if (c.basin_hasher_init(&h.c_hasher) != 0) return BasinError.InitFailed;
        h.initialized = true;
        return h;
    }

    /// Absorb more data. Can be called multiple times
    pub fn update(self: *Hasher, data: []const u8)!void {
        if (c.basin_hasher_update(&self.c_hasher, data.ptr, data.len) != 0) {
            return BasinError.HashFailed;
        }
    }

    /// Finalize and write 32 bytes to out
    pub fn final(self: *Hasher, out: *[32]u8)!void {
        if (c.basin_hasher_final(&self.c_hasher, out)!= 0) {
            return BasinError.HashFailed;
        }
        self.initialized = false;
    }

    /// Convenience: final + hex
    pub fn finalHex(self: *Hasher, allocator: std.mem.Allocator)![]u8 {
        var out: [32]u8 = undefined;
        try self.final(&out);
        return try toHex(&out, allocator);
    }

    pub fn deinit(self: *Hasher) void {
        _ = self; // C hasher is stack only
    }
};