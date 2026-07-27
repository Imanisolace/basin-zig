const std = @import("std");

const ConstantsFile = @embedFile("constants.json"); // <-- removed../

const PoseidonConstants = struct {
    c: [90]u64,
    mds: [3][3]u64,
};

const parsed_constants = blk: { // <-- removed comptime keyword
    const parsed = std.json.parseFromSlice(PoseidonConstants, ConstantsFile,.{}) catch @compileError("Bad constants.json");
    break :blk parsed.value;
};

const C = parsed_constants.c;
const MDS = parsed_constants.mds;

fn addMod(a: u64, b: u64) u64 { return (a +% b); }
fn mulMod(a: u64, b: u64) u64 { return (a *% b); }

fn poseidonPerm(state: *[3]u64, round: usize) void {
    for (0..3) |i| state[i] +%= C[round * 3 + i];
    if (round < 4 or round >= 4 + 22) {
        for (0..3) |i| state[i] = state[i] *% state[i] *% state[i] *% state[i] *% state[i];
    }
    var new: [3]u64 =.{0,0,0};
    for (0..3) |i| for (0..3) |j| new[i] +%= mulMod(MDS[i][j], state[j]);
    state.* = new;
}

fn poseidonHash(inputs: [3]u64) u64 {
    var s = inputs;
    for (0..30) |r| poseidonPerm(&s, r);
    return s[0];
}

fn hashPair(left: u64, right: u64) u64 {
    return poseidonHash(.{left, right, 0});
}

pub fn computeRoot(leaves: []const u64) u64 {
    var buf: [1024]u64 = undefined;
    @memcpy(buf[0..leaves.len], leaves);
    var n = leaves.len;
    while (n > 1) {
        var i: usize = 0;
        while (i < n) : (i += 2) {
            const l = buf[i];
            const r = if (i + 1 < n) buf[i + 1] else l;
            buf[i / 2] = hashPair(l, r);
        }
        n = (n + 1) / 2;
    }
    return buf[0];
}

test "compiles" {
    const root = computeRoot(&[_]u64{1,2,3,4});
    try std.testing.expect(root != 0);
}