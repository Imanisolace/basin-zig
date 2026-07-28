const std = @import("std");

pub const Fr = struct {
    pub const zero = Fr{.v = [_]u8{0} ** 32 };

    v: [32]u8,

    pub fn fromBytes(b: [32]u8) Fr {
        return Fr{.v = b };
    }

    pub fn toBytes(self: Fr) [32]u8 {
        return self.v;
    }

    pub fn add(self: Fr, other: Fr) Fr {
        // TODO: real BN254 field add mod p
        var res: [32]u8 = undefined;
        for (0..32) |i| res[i] = self.v[i] +% other.v[i];
        return Fr{.v = res };
    }

    pub fn mul(self: Fr, other: Fr) Fr {
        // TODO: real BN254 field mul mod p
        var res: [32]u8 = undefined;
        for (0..32) |i| res[i] = self.v[i] *% other.v[i];
        return Fr{.v = res };
    }
};