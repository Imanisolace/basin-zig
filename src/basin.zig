const std = @import("std");
const poseidon = @import("poseidon.zig");

pub const BLOCK_SIZE = 16;
pub const OUTPUT_SIZE = 32;

pub const BasinError = error{
    EmptyInput,
};

pub const Hasher = struct {
    state: [3]u64 = .{ 0, 0, 0 },
    buffer: [BLOCK_SIZE]u8 align(8) = .{0} ** BLOCK_SIZE,
    buf_len: usize = 0,

    pub fn init() Hasher {
        return .{};
    }

    fn absorbBlock(self: *Hasher) void {
        const block = std.mem.bytesAsSlice(u64, &self.buffer);

        self.state[0] = poseidon.add(self.state[0], block[0]);
        self.state[1] = poseidon.add(self.state[1], block[1]);

        poseidon.permute(&self.state);
        self.buf_len = 0;
        @memset(&self.buffer, 0);
    }

    pub fn update(self: *Hasher, data: []const u8) void {
        var i: usize = 0;
        while (i < data.len) {
            const to_copy = @min(BLOCK_SIZE - self.buf_len, data.len - i);
            @memcpy(self.buffer[self.buf_len..][0..to_copy], data[i..][0..to_copy]);
            self.buf_len += to_copy;
            i += to_copy;
            if (self.buf_len == BLOCK_SIZE) self.absorbBlock();
        }
    }

    pub fn final(self: *Hasher, out: *[OUTPUT_SIZE]u8) void {
        self.buffer[self.buf_len] = 0x01;
        self.buf_len += 1;

        @memset(self.buffer[self.buf_len..], 0);
        self.absorbBlock();

        std.mem.writeInt(u64, out[0..8], self.state[0], .little);
        std.mem.writeInt(u64, out[8..16], self.state[1], .little);

        poseidon.permute(&self.state);

        std.mem.writeInt(u64, out[16..24], self.state[0], .little);
        std.mem.writeInt(u64, out[24..32], self.state[1], .little);
    }
};

pub fn poseidonHash(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (input.len == 0) return BasinError.EmptyInput;

    var h = Hasher.init();
    h.update(input);

    const out = try allocator.alloc(u8, OUTPUT_SIZE);
    errdefer allocator.free(out);

    h.final(out[0..OUTPUT_SIZE]);
    return out;
}

// FIXED: Replaced non-existent allocPrintHex with standard allocPrintHexLower
pub fn toHex(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrintHexLower(allocator, input);
}

pub fn hash3(a: u64, b: u64, c: u64) u64 {
    return poseidon.hash3(a, b, c);
}
