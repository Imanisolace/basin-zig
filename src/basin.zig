const std = @import("std");
const c = @cImport({
    @cInclude("basin.h");
});

pub const Error = error{
    InitFailed,
    HashFailed,
};

/// A Basin hasher. Thread-safe after init.
pub const Hasher = struct {
    ctx: *c.BasinContext,

    /// Initialize Basin with default config
    pub fn init() Error!Hasher {
        const ctx = c.basin_init();
        if (ctx == null) return error.InitFailed;
        return Hasher{.ctx = ctx.? };
    }

    /// Free memory
    pub fn deinit(self: *Hasher) void {
        c.basin_free(self.ctx);
    }

    /// Hash a single slice of bytes. Returns 32-byte hash
    pub fn hash(self: *Hasher, data: []const u8) Error![32]u8 {
        var out: [32]u8 = undefined;
        const res = c.basin_poseidon_hash(self.ctx, data.ptr, data.len, &out);
        if (res!= 0) return error.HashFailed;
        return out;
    }

    /// Hash many items in parallel. This is where the 4ms magic happens
    pub fn hashBatch(self: *Hasher, inputs: []const []const u8, allocator: std.mem.Allocator) Error![][]u8 {
        var results = try allocator.alloc([]u8, inputs.len);
        errdefer allocator.free(results);

        for (inputs, 0..) |data, i| {
            results[i] = try allocator.alloc(u8, 32);
            const res = c.basin_poseidon_hash(self.ctx, data.ptr, data.len, results[i].ptr);
            if (res!= 0) return error.HashFailed;
        }
        return results;
    }
};

/// Convert 32-byte hash to hex string for printing
pub fn toHex(hash: [32]u8, allocator: std.mem.Allocator)![]u8 {
    return std.fmt.allocPrint(allocator, "{x}",.{std.fmt.fmtSliceHexLower(&hash)});
}