const std = @import("std");
const consts = @import("poseidon_consts");
const Fr = @import("fr").Fr;

pub const BLOCK_SIZE = 64; // 2 field elements absorbed per block (rate = 2)
pub const OUTPUT_SIZE = 32; // one field element squeezed out

pub const BasinError = error{
    EmptyInput,
};

pub const Hasher = struct {
    state: [3]Fr = .{ Fr.zero, Fr.zero, Fr.zero },
    buffer: [BLOCK_SIZE]u8 = .{0} ** BLOCK_SIZE,
    buf_len: usize = 0,

    pub fn init() Hasher {
        return .{};
    }

    fn absorbBlock(self: *Hasher) void {
        var a_bytes: [32]u8 = undefined;
        var b_bytes: [32]u8 = undefined;
        @memcpy(&a_bytes, self.buffer[0..32]);
        @memcpy(&b_bytes, self.buffer[32..64]);

        self.state[0] = self.state[0].add(Fr.fromBytes(a_bytes));
        self.state[1] = self.state[1].add(Fr.fromBytes(b_bytes));

        self.state = consts.poseidon_perm(self.state);
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

        out.* = self.state[0].toBytes();
    }
};

pub fn poseidonHash(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (input.len == 0) return BasinError.EmptyInput;

    var h = Hasher.init();
    h.update(input);

    var out_arr: [OUTPUT_SIZE]u8 = undefined;
    h.final(&out_arr);

    const out = try allocator.alloc(u8, OUTPUT_SIZE);
    @memcpy(out, &out_arr);
    return out;
}

pub fn toHex(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator, "{}", .{std.fmt.fmtSliceHexLower(input)});
}