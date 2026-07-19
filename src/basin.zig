const std = @import("std");

const c = @cImport({
    @cInclude("basin.h"); // ONLY THIS ONE
});

pub const BasinConfig = struct {
    width: u32,
    height: u32,
    channels: u32,
};

pub fn init(cfg: BasinConfig) !void {
    const c_cfg = c.basin_config_t{
        .width = cfg.width,
        .height = cfg.height,
        .channels = cfg.channels,
    };
    if (c.basin_init(c_cfg) != 0) {
        return error.InitFailed;
    }
}

pub fn deinit() void {
    c.basin_deinit();
}

pub fn poseidonHash(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const out = try allocator.alloc(u8, 32);
    errdefer allocator.free(out);
    c.basin_poseidon_hash(input.ptr, input.len, out.ptr);
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
