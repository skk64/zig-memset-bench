const std = @import("std");
const assert = std.debug.assert;

export fn memset_basic(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    @setRuntimeSafety(false);
    for (dest.?[0..len]) |*i| i.* = c;
    return dest;
}

export fn memset_ericlang(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    @setRuntimeSafety(false);

    const n = std.simd.suggestVectorLength(u8) orelse @sizeOf(usize);

    var i: usize = 0;
    while (i + n <= len) : (i += n) {
        const p: *align(1) @Vector(n, u8) = @ptrCast(dest.?[i..]);
        p.* = @splat(c);
    }
    while (i < len) : (i += 1) {
        dest.?[i] = c;
    }

    return dest;
}

fn memset_rpkak_small(
    log_min: comptime_int,
    log_max: comptime_int,
    d: [*]u8,
    c: u8,
    len: usize,
) void {
    if (log_min + 1 != log_max) {
        const mid = (log_min + log_max) / 2;
        if (len <= 1 << mid) {
            memset_rpkak_small(log_min, mid, d, c, len);
        } else {
            memset_rpkak_small(mid, log_max, d, c, len);
        }
    } else {
        const size = 1 << log_min;
        const filled = if (size > @sizeOf(usize))
            @as(@Vector(size, u8), @splat(c))
        else blk: {
            var filled: @Int(.unsigned, 8 * size) = undefined;
            @as(*[size]u8, @ptrCast(&filled)).* = @splat(c);
            break :blk filled;
        };

        const first_unaligned_ptr: *align(1) @TypeOf(filled) = @ptrCast(d);
        first_unaligned_ptr.* = filled;
        const last_unaligned_ptr: *align(1) @TypeOf(filled) = @ptrCast(d + len - size);
        last_unaligned_ptr.* = filled;
    }
}

export fn memset_rpkak(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    const max_size = std.simd.suggestVectorLength(u8) orelse @sizeOf(usize);

    const d = dest.?;

    if (len <= max_size) {
        if (len == 0) return dest;

        memset_rpkak_small(0, @ctz(@as(usize, max_size)), d, c, len);
    } else {
        const filled = if (max_size > @sizeOf(usize))
            @as(@Vector(max_size, u8), @splat(c))
        else blk: {
            var filled: @Int(.unsigned, max_size) = undefined;
            @as(*[max_size]u8, @ptrCast(&filled)).* = @splat(c);
            break :blk filled;
        };

        const first_unaligned_ptr: *align(1) @TypeOf(filled) = @ptrCast(d);
        first_unaligned_ptr.* = filled;

        if (len > 2 * max_size) {
            const begin_aligned = std.mem.alignForward(usize, @intFromPtr(d) + 1, max_size);
            const end_aligned = std.mem.alignBackward(usize, @intFromPtr(d) + len - 1, max_size);

            const aligned_ptr: [*]align(max_size) u8 = @ptrFromInt(begin_aligned);
            const aligned_slice = aligned_ptr[0 .. end_aligned - begin_aligned];

            const vec_slice: []@TypeOf(filled) = @ptrCast(aligned_slice);

            // When using a for(vec_slice) loop, LLVM will add a branch, for the impossible case, that vec_slice.len == 0.
            var i: usize = 0;
            while (true) {
                vec_slice[i] = filled;

                i += 1;
                if (i == vec_slice.len)
                    break;
            }
        }

        const last_unaligned_ptr: *align(1) @TypeOf(filled) = @ptrCast(d + len - max_size);
        last_unaligned_ptr.* = filled;
    }

    return dest;
}

export fn memset_skk64(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    @setRuntimeSafety(false);

    const n = std.simd.suggestVectorLength(u8) orelse @sizeOf(usize);

    if (len < n) {
        // if len < n, then write entire range in 2 writes, using largest vector write available
        // There is some overlap in the write, but it is faster than writing individual bytes
        switch (@bitSizeOf(usize) - @clz(len)) {
            0 => {},
            inline 1...@ctz(@as(usize, n)) => |bits| {
                const vec_bits = bits - 1;
                const vec_bytes = 1 << vec_bits;
                const Vec = @Vector(vec_bytes, u8);
                @as(*align(1) Vec, @ptrCast(dest.?)).* = @splat(c);
                @as(*align(1) Vec, @ptrCast(dest.?[len - vec_bytes ..])).* = @splat(c);
            },

            else => unreachable,
        }
        return dest;
    }
    const Vec = @Vector(n, u8);
    // Iterating over a slice instead of a pointer offset will cause llvm to
    // automatically unroll the loop for x86_64 (as of zig-0.17-dev.704)
    const slice = dest.?[0..len];
    const vec_slice: []align(1) Vec = @ptrCast(slice);

    for (vec_slice) |*i| i.* = @splat(c);
    @as(*align(1) Vec, @ptrCast(dest.?[len - n ..])).* = @splat(c);

    return dest;
}

export fn memset_skk64_2(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    const n = std.simd.suggestVectorLength(u8) orelse @sizeOf(usize);

    if (len <= n * 2) {
        // if len <= 2*n, then write entire range in 2 writes, using largest vector write available
        // There is some overlap in the write, but it is faster than writing individual bytes
        switch (@bitSizeOf(usize) - @clz(len)) {
            0 => {},
            1 => dest.?[0] = c,
            inline 2...@ctz(@as(usize, n)) + 2 => |bits| {
                const vec_bits = bits - 1;
                const vec_bytes = @min(n, 1 << vec_bits);
                dest.?[0..vec_bytes].* = @splat(c);
                dest.?[len - vec_bytes ..][0..vec_bytes].* = @splat(c);
            },
            else => unreachable,
        }
        return dest;
    }
    // Iterating over a slice instead of a pointer offset will cause llvm to
    // automatically unroll the loop for x86_64 (as of zig-0.16)
    // Example: https://godbolt.org/z/q1fzv6Ksb
    //
    // Longer writes are written to aligned addresses as it is up to 20%
    // faster if the memory is already loaded into L1 cache
    // (see https://codeberg.org/ziglang/zig/issues/32091#issuecomment-17283716)
    const start = std.mem.alignForward(usize, @intFromPtr(dest.?), n) - @intFromPtr(dest.?);
    const end = std.mem.alignBackward(usize, @intFromPtr(dest.? + len), n) - @intFromPtr(dest.?);
    const vec_slice: []@Vector(n, u8) = @ptrCast(@alignCast(dest.?[start..end]));

    dest.?[0..n].* = @splat(c);
    for (vec_slice) |*i| i.* = @splat(c);
    dest.?[len - n ..][0..n].* = @splat(c);

    return dest;
}

/// handles end using duffs device
export fn memset_duffs(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    const n = std.simd.suggestVectorLength(u8) orelse @sizeOf(usize);
    const splatted: @Vector(n, u8) = @splat(c);

    sw: switch (len % n) {
        inline 1...n - 1 => |rem| {
            dest.?[rem - 1] = c;
            continue :sw rem - 1;
        },
        0 => {},
        else => unreachable,
    }

    var i: usize = len % n;
    while (i + n <= len) : (i += n) {
        dest.?[i..][0..n].* = splatted;
    }

    return dest;
}

export fn memset_builtin(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    @memset(dest.?[0..len], c);
    return dest;
}
