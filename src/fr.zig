const std = @import("std");
const big = @import("bigzig");

// BN254 prime: 21888242871839275222246405745257275088548364400416034343698204186575808495617
const P = big.Int(u256).from(u256, 21888242871839275222246405745257275088548364400416034343698204186575808495617);
const P_U256: u256 = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

pub const Fr = struct {
    v: big.Int(u256),

    pub const zero = Fr{ .v = big.Int(u256).init(0) };
    pub const one = Fr{ .v = big.Int(u256).init(1) };

    pub fn fromBytes(b: [32]u8) Fr {
        const x = std.mem.readInt(u256, &b, .little);
        var res = big.Int(u256).from(u256, x);
        if (res.cmp(P) != .lt) res = res.mod(P);
        return Fr{ .v = res };
    }

    pub fn toBytes(self: Fr) [32]u8 {
        const x = self.v.to(u256);
        var out: [32]u8 = undefined;
        std.mem.writeInt(u256, &out, x, .little);
        return out;
    }

    pub fn add(self: Fr, other: Fr) Fr {
        var sum = self.v.add(other.v);
        if (sum.cmp(P) != .lt) sum = sum.sub(P);
        return Fr{ .v = sum };
    }

    pub fn sub(self: Fr, other: Fr) Fr {
        if (self.v.cmp(other.v) == .lt) {
            const tmp = P.sub(other.v).add(self.v);
            return Fr{ .v = tmp };
        } else {
            return Fr{ .v = self.v.sub(other.v) };
        }
    }

    
    // mod-P step.
    pub fn mul(self: Fr, other: Fr) Fr {
        const a: u512 = self.v.to(u256);
        const b: u512 = other.v.to(u256);
        const prod: u512 = a * b;
        const p_wide: u512 = P_U256;
        const reduced: u256 = @intCast(prod % p_wide);
        return Fr{ .v = big.Int(u256).from(u256, reduced) };
    }

    pub fn eq(self: Fr, other: Fr) bool {
        return self.v.cmp(other.v) == .eq;
    }
};