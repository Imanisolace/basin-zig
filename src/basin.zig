const std = @import("std");

const c = @cImport({
    @cInclude("basin.h");
});

/// Public errors
pub const BasinError = error{
    InitFailed,
    HashFailed,
    EmptyInput,
};

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

/// One-shot Poseidon hash. Returns 32 bytes.
pub fn poseidonHash(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    if (input.len == 0) {
        return BasinError.EmptyInput;
    }

    var out_stack: [32]u8 = undefined;
    const rc = c.basin_poseidon_hash(input.ptr, input.len, &out_stack);
    if (rc != 0) {
        return BasinError.HashFailed;
    }
    return try allocator.dupe(u8, &out_stack);
}

/// Streaming Hasher backed by C basin_hasher_t
pub const Hasher = struct {
    c_hasher: c.basin_hasher_t,

    /// Start a new hash
    pub fn init()!Hasher {
        var h: Hasher = undefined;
        if (c.basin_hasher_init(&h.c_hasher) != 0) return BasinError.InitFailed;
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
        if (c.basin_hasher_final(&self.c_hasher, out) != 0) {
            return BasinError.HashFailed;
        }
    }

    /// Convenience: final + hex
    pub fn finalHex(self: *Hasher, allocator: std.mem.Allocator)![]u8 {
        var out: [32]u8 = undefined;
        try self.final(&out);
        return try toHex(&out, allocator);
    }
};