const std = @import("std");
const c = @cImport({
    @cInclude("basin.h");
});

pub const BasinConfig = struct {
    width: u32,
    height: u32,
    channels: u32,
};

pub fn init(cfg: BasinConfig)!void {
    const res = c.basin_init(&c.BasinConfig{
       .width = cfg.width,
       .height = cfg.height,
       .channels = cfg.channels,
    });
    if (res!= 0) return error.InitFailed;
}

pub fn deinit() void {
    c.basin_free();
}

pub fn poseidonHash(input: []const u8, allocator: std.mem.Allocator)![]u8 {
    var out: [32]u8 = undefined;
    const res = c.basin_poseidon_hash(input.ptr, input.len, &out);
    if (res!= 0) return error.HashFailed;
    return try allocator.dupe(u8, &out);
}

pub fn parallelProcess(data: []const u8, threads: i32)!void {
    const res = c.basin_parallel_process(data.ptr, data.len, threads);
    if (res!= 0) return error.ParallelFailed;
}

pub fn toHex(bytes: []const u8, allocator: std.mem.Allocator)![]u8 {
    return std.fmt.allocPrint(allocator, "{s}",.{std.fmt.fmtSliceHexLower(bytes)});
}
