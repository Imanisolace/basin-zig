const std = @import("std");
const poseidon = @import("poseidon.zig");

// Rate = 2 elements = 16 bytes. Capacity = 1 element = 8 bytes
pub const BLOCK_SIZE = 16;
pub const OUTPUT_SIZE = 32;

pub const Hasher = struct {
    state: [3]u64 =.{0, 0, 0},
    buffer: [BLOCK_SIZE]u8 align(8) =.{0} ** BLOCK_SIZE,
    buf_len: usize = 0,

    pub fn init() Hasher {
        return.{};
    }

    fn absorbBlock(self: *Hasher) void {
        const block = std.mem.bytesAsSlice(u64, &self.buffer);

        // Absorb into rate positions only. Leave state[2] as capacity
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
        // Injective 10*1 padding. Safe for buf_len == 0..16
        self.buffer[self.buf_len] = 0x01;
        self.buf_len += 1;

        // Zero pad the rest of the block
        @memset(self.buffer[self.buf_len..], 0);
        self.absorbBlock();

        // Squeeze 32 bytes: rate -> permute -> rate
        std.mem.writeInt(u64, out[0..8], self.state[0],.little);
        std.mem.writeInt(u64, out[8..16], self.state[1],.little);

        poseidon.permute(&self.state);

        std.mem.writeInt(u64, out[16..24], self.state[0],.little);
        std.mem.writeInt(u64, out[24..32], self.state[1],.little);
    }
};

pub fn hash(input: []const u8, out: *[OUTPUT_SIZE]u8) void {
    var h = Hasher.init();
    h.update(input);
    h.final(out);
}

pub fn hash3(a: u64, b: u64, c: u64) u64 {
    return poseidon.hash3(a, b, c);
}

test "basin hash padding edge cases" {
    var out1: [OUTPUT_SIZE]u8 = undefined;
    var out2: [OUTPUT_SIZE]u8 = undefined;
    hash("", &out1); // empty
    hash(&[_]u8{0x01}, &out2); // 1 byte
    try std.testing.expect(!std.mem.eql(u8, &out1, &out2)); // must not collide
}