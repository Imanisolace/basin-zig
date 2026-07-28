const std = @import("std");

pub const Fr = struct {
    limbs: [4]u64, // BN254 fits in 4x64

    pub const zero = Fr{.limbs = [_]u64{0} ** 4 };

    pub fn fromBytes(b: [32]u8) Fr {
        return Fr{.limbs =.{
            std.mem.readInt(u64, b[0..8],.little),
            std.mem.readInt(u64, b[8..16],.little),
            std.mem.readInt(u64, b[16..24],.little),
            std.mem.readInt(u64, b[24..32],.little),
        }};
    }

    pub fn toBytes(self: Fr) [32]u8 {
        var out: [32]u8 = undefined;
        std.mem.writeInt(u64, out[0..8], self.limbs[0],.little);
        std.mem.writeInt(u64, out[8..16], self.limbs[1],.little);
        std.mem.writeInt(u64, out[16..24], self.limbs[2],.little);
        std.mem.writeInt(u64, out[24..32], self.limbs[3],.little);
        return out;
    }

    pub fn add(self: Fr, other: Fr) Fr {
        // Fake add for now - real needs mod P. But use u128 to avoid byte overflow
        var res: [4]u64 = undefined;
        for (0..4) |i| res[i] = self.limbs[i] +% other.limbs[i];
        return Fr{.limbs = res};
    }

    pub fn mul(self: Fr, other: Fr) Fr {
        // Fake mul for now
        var res: [4]u64 = undefined;
        for (0..4) |i| res[i] = self.limbs[i] *% other.limbs[i];
        return Fr{.limbs = res};
    }
};