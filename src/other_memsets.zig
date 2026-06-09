const std = @import("std");
const assert = std.debug.assert;

pub export fn memset_ericlang(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
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
        const filled = @as(@Vector(size, u8), @splat(c));
        // const filled = if (size > @sizeOf(usize))
        //     @as(@Vector(size, u8), @splat(c))
        // else blk: {
        //     var filled: @Int(.unsigned, 8 * size) = undefined;
        //     @as(*[size]u8, @ptrCast(&filled)).* = @splat(c);
        //     break :blk filled;
        // };

        const first_unaligned_ptr: *align(1) @TypeOf(filled) = @ptrCast(d);
        first_unaligned_ptr.* = filled;
        const last_unaligned_ptr: *align(1) @TypeOf(filled) = @ptrCast(d + len - size);
        last_unaligned_ptr.* = filled;
    }
}

pub export fn memset_rpkak(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
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

pub export fn memset_skk64_align(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    @setRuntimeSafety(false);

    const n = std.simd.suggestVectorLength(u8) orelse @sizeOf(usize);

    if (len < n) {
        // if len < n, then write entire range in 2 unaligned writes, using largest vector write possible
        // There is some overlap in the write, but it is faster than writing individual bytes
        const max_bits = @ctz(@as(usize, n));
        const len_max_bits = @bitSizeOf(usize) - @clz(len);
        switch (len_max_bits) {
            0 => {},
            inline 1...max_bits => |bits| {
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

    const n_aligned: [*]align(n) u8 = @ptrFromInt(std.mem.alignForward(usize, @intFromPtr(dest.?) + 1, n));
    const align_offset: usize = n_aligned - dest.?;
    const slice = n_aligned[0 .. len - align_offset];
    const vec_slice: []Vec = @ptrCast(slice);

    @as(*align(1) Vec, @ptrCast(dest.?)).* = @splat(c);
    for (vec_slice) |*i| i.* = @splat(c);
    @as(*align(1) Vec, @ptrCast(dest.?[len - n ..])).* = @splat(c);

    return dest;
}

pub export fn memset_skk64(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    @setRuntimeSafety(false);

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

pub export fn memset_builtin(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    @memset(dest.?[0..len], c);
    return dest;
}

pub extern fn memset_musl_asm(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
