const std = @import("std");

const WIDTH = 3;
const RF = 8;
const RP = 55;
const ROUNDS = RF + RP; // 63

// Goldilocks Field Prime: 2^64 - 2^32 + 1
pub const P: u64 = 0xFFFFFFFF00000001; // CORRECT 64-bit value

// Custom RCs for t=3. Internal use only. Not Plonky2 compatible.
pub const RC: [ROUNDS * WIDTH]u64 = .{
    0xd9c2e7304c6e7d89, 0x1a9b8c7d6e5f4032, 0x3f2e1d0c9b8a7968, 0x4a5968778695a4b3, 0x5b6a798887a6b5c4, 0x6c7b8a9a98b7c6d5,
    0x7d8c9bab09c8d7e6, 0x8e9dacbc1ad9e8f7, 0x9fadbdcd2beaf908, 0xb0becedf3cfb0a19, 0xc1cfdfe04d0c1b2a, 0xd2e0f0f15e1d2c3b,
    0xe3f101026f2e3d4c, 0xf4021213803f4e5d, 0x0513232490515f6e, 0x162434355a61607f, 0x274545466b727190, 0x385656577c8382a1,
    0x496767688d9493b2, 0x5a7879799ea5a4c3, 0x6b89898aafb6b5d4, 0x7c9a9a9bc0c7c6e5, 0x8dababacd1d8d7f6, 0x9ebcbccde2e9e807,
    0x00afcddef3faf918, 0xc0dedfef04fba029, 0xd1eff0f015fcb13a, 0xe2000101260d02cb, 0xf3111212371e13dc, 0x04222323482f24ed,
    0x153334345940350e, 0x264545456a4b461f, 0x375656567b5c5730, 0x486767688c6d6841, 0x597878799d7e7952, 0x6a89898aae8f8a63,
    0x7b9a9a9bbf909b74, 0x8cababacc0a1ac85, 0x9dbcbdcd1bb2bd96, 0xadcdcde2cc3ccea7, 0xbededefd3dddfdb8, 0x00cffffef0e4ede0,
    0x000e000011f0101d, 0x00f11112301212eb, 0x02222223412323fc, 0x133333345234340d, 0x244444455345451e, 0x355555566456562f,
    0x4666666775676740, 0x5777777886787851, 0x6888888997898962, 0x7999999aa8989a73, 0x8aaaaaabbb9a9b84, 0x9bbbbbbcccaabcb5,
    0xacccccdddcbdbdc6, 0xbddeadfeeececed7, 0xceeeeeffdffedfe8, 0xdf012345f00e0ef9, 0xe0f0e0d0c0b0a0a0, 0xa1a2a3a4b5b6b7b8,
    0xc9c8c7c6d5d4d3d2, 0xebeae9e8f7f6f5f4, 0x0d0c0b0a19181716, 0x2f2e2d2c3b3a3938, 0x514f4e4d5d5c5b5a, 0x737271706f6e6d6c,
    0x9594939291908f8e, 0xb7b6b5b4b3b2b1b0, 0xd9d8d7d6f5f4f3f2, 0xfbfaf9f817161514, 0x1d1c1b1a39383736, 0x3f3e3d3c5b5a5958,
    0x61605f5e7d7c7b7a, 0x838281808f8e8d8c, 0xa5a4a3a2b1b0afae, 0xc7c6c5c4d3d2d1d0, 0xe9e8e7e6f5f4f3f2, 0x0b0a090817161514,
    0x2d2c2b2a39383736, 0x4f4e4d4c5b5a5958, 0x71706f6e7d7c7b7a, 0x939291908f8e8d8c, 0xb5b4b3b2a1a09f9e, 0xd7d6d5d4c3c2c1c0,
    0xf9f8f7f6e5e4e3e2, 0x1b1a191817161514, 0x3d3c3b3a39383736, 0x5f5e5d5c5b5a5958, 0x81807f7e7d7c7b7a, 0xa3a2a1a09f9e9d9c,
    0xc5c4c3c2b1b0afae, 0xe7e6e5e4d3d2d1d0, 0x0908070605040302, 0x2b2a292827262524, 0x4d4c4b4a49484746, 0x6f6e6d6c6b6a6968,
    0x91908f8e8d8c8b8a, 0xb3b2b1b0afaeadac, 0xd5d4d3d2d1d0cfce, 0xf7f6f5f4f3f2f1f0, 0x1918171615141312, 0x3b3a393837363534,
    0x5d5c5b5a59585756, 0x7f7e7d7c7b7a7978, 0xa1a09f9e9d9c9b9a, 0xc3c2c1c0bfbebdbc, 0xe5e4e3e2e1e0dfde, 0x0706050403020100,
    0x2928272625242322, 0x4b4a494847464544, 0x6d6c6b6a69686766, 0x8f8e8d8c8b8a8988, 0xb1b0afaeadacabab, 0xd3d2d1d0cfcecdcc,
    0xf5f4f3f2f1f0efee, 0x1716151413121110, 0x3938373635343332, 0x5b5a595857565554, 0x7d7c7b7a79787776, 0x9f9e9d9c9b9a9998,
    0xc1c0bfbebdbcbbba, 0xe3e2e1e0dfdedddc, 0x050403020100fffe, 0x2726252423222120, 0x4948474645444342, 0x6b6a696867666564,
    0x8d8c8b8a89888786, 0xafaeadacabaaa9a8, 0xd1d0cfcecdcccbca, 0xf3f2f1f0efeeedec, 0x1514131211100f0e, 0x3736353433323130,
    0x5958575655545352, 0x7b7a797877767554, 0x9d9c9b9a99989796, 0xbfbebdbcbbbab9b8, 0xe1e0dfdedddcdbda, 0x03020100fffefdfc,
    0x2524232221201f1e, 0x4746454443424140, 0x6968676665646362, 0x8b8a898887868554, 0xadacabaaa9a8a7a6, 0xcfcecdcccbcab9b8,
    0xf1f0efeeedecebea, 0x131211100f0e0d0c, 0x3534333231302f2e, 0x5756555453525150, 0x7978777675545352, 0x9b9a999897969554,
    0xbdbcbbbab9b8b7b6, 0xdfdedddcdbdad9d8, 0x0100fffefdfcfbfa,
};

// MDS for t=3
pub const MDS: [WIDTH][WIDTH]u64 = .{
    .{ 0x0000000000000005, 0x0000000000001, 0x0000000000000001 },
    .{ 0x0000000000000001, 0x0000000000000005, 0x0000000000000001 },
    .{ 0x0000000000000001, 0x0000000000001, 0x0000000000000005 },
};

inline fn add(a: u64, b: u64) u64 {
    return @as(u64, (@as(u128, a) + b) % P);
}

inline fn mul(a: u64, b: u64) u64 {
    return @as(u64, (@as(u128, a) * b) % P);
}

fn pow5(x: u64) u64 {
    const x2 = mul(x, x);
    const x4 = mul(x2, x2);
    return mul(x4, x);
}

fn applyMDS(s: *[WIDTH]u64) void {
    var result: [WIDTH]u64 = [_]u64{0} ** WIDTH;
    inline for (0..WIDTH) |i| {
        var sum: u128 = 0;
        inline for (0..WIDTH) |j| {
            // FIX: Restored the modular wrap function to clear implicit overflows
            sum += mul(s[j], MDS[i][j]); 
        }
        result[i] = @as(u64, sum % P);
    }
    s.* = result;
}

pub fn permute(s: *[WIDTH]u64) void {
    var round: usize = 0;
    for (0..RF / 2) |_| {
        for (0..WIDTH) |i| s[i] = add(s[i], RC[round * WIDTH + i]);
        for (0..WIDTH) |i| s[i] = pow5(s[i]);
        applyMDS(s);
        round += 1;
    }
    for (0..RP) |_| {
        for (0..WIDTH) |i| s[i] = add(s[i], RC[round * WIDTH + i]);
        s[0] = pow5(s[0]);
        applyMDS(s);
        round += 1;
    }
    for (0..RF / 2) |_| {
        for (0..WIDTH) |i| s[i] = add(s[i], RC[round * WIDTH + i]);
        for (0..WIDTH) |i| s[i] = pow5(s[i]);
        applyMDS(s);
        round += 1;
    }
}

pub fn hash3(a: u64, b: u64, c: u64) u64 {
    var s = [WIDTH]u64{ a, b, c };
    permute(&s);
    return s[0];
}

test "sanity" {
    const h = hash3(0, 0, 0);
    std.debug.print("hash3(0,0,0) = 0x{x}\n", .{h});
}
