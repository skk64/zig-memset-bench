const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;

const impl = struct {
    extern fn memset(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn memset_ericlang(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn memset_duffs(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn memset_skk64(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn memset_rpkak(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn memset_builtin(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn memset_basic(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn memset_musl_asm(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn __memset_avx2_unaligned(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn __memset_avx512_unaligned(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
    extern fn __memset_sve_zva64(dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8;
};

/// Selects the memset based on input name
fn memset_fn(
    name: []const u8,
) !*const fn (dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8 {
    if (std.mem.eql(u8, name, "ericlang")) return impl.memset_ericlang;
    if (std.mem.eql(u8, name, "duffs")) return impl.memset_duffs;
    if (std.mem.eql(u8, name, "skk64")) return impl.memset_skk64;
    if (std.mem.eql(u8, name, "rpkak")) return impl.memset_rpkak;
    if (std.mem.eql(u8, name, "builtin")) return impl.memset_builtin;
    if (std.mem.eql(u8, name, "basic")) return impl.memset_basic;
    if (std.mem.eql(u8, name, "libc")) return impl.memset;

    switch (builtin.cpu.arch) {
        .x86_64 => {
            if (std.mem.eql(u8, name, "musl_asm")) return impl.memset_musl_asm;
            if (std.mem.eql(u8, name, "glibc_avx2")) return impl.__memset_avx2_unaligned;
            if (std.mem.eql(u8, name, "glibc_avx512")) return impl.__memset_avx512_unaligned;
        },
        .aarch64 => {
            // Arm assembly won't compile
            // if (std.mem.eql(u8, name, "glibc_zva64")) return impl.__memset_sve_zva64;
        },
        else => {},
    }
    return error.NoMatch;
}
pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);

    if (args.len < 4) {
        std.debug.print("Usage: {} [memset name] [total bytes written] [bytes written per memset call]\n", .{args[0]});
        return error.NotEnoughArgs;
    }

    const memset = memset_fn(args[1]) catch (e) {
        std.debug.print("{} doesn't match any memset\n", .{args[1]});
        // std.debug.print("\n", .{});
        return e;
    };
    const size = try std.fmt.parseInt(usize, args[2], 10);
    const segment_size = try std.fmt.parseInt(usize, args[3], 10);
    const will_print_time = (args.len > 4) and std.mem.eql(u8, "-p", args[4]);

    try memset_behaviour(22, memset);
    try memset_behaviour(30, memset);
    try memset_behaviour(77, memset);
    try memset_behaviour(770, memset);

    const data = try arena.alloc(u8, size);
    const duration = bench_memset(memset, data, 55, segment_size, io);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    if (will_print_time) try print_time(duration, stdout_writer);

    try stdout_writer.flush(); // Don't forget to flush!
}

fn bench_memset(
    memset: *const fn (dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8,
    data: []u8,
    value: u8,
    segment_size: usize,
    io: Io,
) u64 {
    const start = std.Io.Clock.awake.now(io);
    {
        var i: usize = 0;
        while (i + segment_size < data.len) {
            _ = memset(data.ptr + i, value, segment_size);
            i += segment_size;
        }
    }
    const end = Io.Clock.awake.now(io);
    return @intCast(start.durationTo(end).nanoseconds);
}

fn print_time(ns: u64, w: *Io.Writer) !void {
    try w.print("{0:03}:", .{ns / 1_000_000_000});
    try w.print("{0:03}:", .{ns % 1_000_000_000 / 1_000_000});
    try w.print("{0:03}:", .{ns % 1_000_000 / 1_000});
    try w.print("{0:03}\n", .{ns % 1_000});
}

/// basic memset behaviour test
fn memset_behaviour(
    size: comptime_int,
    memset: *const fn (dest: ?[*]u8, c: u8, len: usize) callconv(.c) ?[*]u8,
) !void {
    var buf: [size]u8 = @splat(55);
    _ = memset(buf[1..].ptr, 22, size - 2);
    // std.debug.print("{any}\n\n", .{buf});
    if (buf[0] != 55) return error.Underflow;
    for (buf[1 .. size - 1]) |*i| {
        if (i.* != 22) return error.MissingWrite;
    }
    if (buf[size - 1] != 55) return error.Overflow;
}
