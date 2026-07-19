const std = @import("std");
const c = @cImport({
    @cInclude("basin.h");
});

pub const Hasher = struct {
    ctx: *c.BasinHasher,

    pub fn init()!Hasher {
        const ctx = c.basin_init();
        if (ctx == null) return error.InitFailed;
        return Hasher{.ctx = ctx };
    }

    pub fn deinit(self: *Hasher) void {
        c.basin_free(self.ctx);
    }

    pub fn hash(self: *Hasher, data: []const u8)![]u8 {
        var out: [32]u8 = undefined;
        const res = c.basin_hash(self.ctx, data.ptr, data.len, &out);
        if (res!= 0) return error.HashFailed;
        return try std.heap.page_allocator.dupe(u8, &out);
    }

    pub fn hashBatch(self: *Hasher, inputs: []const []const u8, allocator: std.mem.Allocator)![][]u8 {
        const n = inputs.len;
        var out_ptrs = try allocator.alloc([*c]const u8, n);
        defer allocator.free(out_ptrs);
        var out_lens = try allocator.alloc(usize, n);
        defer allocator.free(out_lens);

        for (inputs, 0..) |inp, i| {
            out_ptrs[i] = inp.ptr;
            out_lens[i] = inp.len;
        }

        var results = try allocator.alloc([]u8, n);
        errdefer {
            for (results) |r| if (r.len > 0) allocator.free(r);
            allocator.free(results);
        }

        const res = c.basin_hash_batch_parallel(self.ctx, out_ptrs.ptr, out_lens.ptr, n, 8);
        if (res!= 0) return error.BatchFailed;

        for (0..n) |i| {
            var buf: [32]u8 = undefined;
            c.basin_get_hash(self.ctx, i, &buf);
            results[i] = try allocator.dupe(u8, &buf);
        }
        return results;
    }
};

pub fn toHex(bytes: []const u8, allocator: std.mem.Allocator)![]u8 {
    return std.fmt.allocPrint(allocator, "{s}",.{std.fmt.fmtSliceHexLower(bytes)});
}
