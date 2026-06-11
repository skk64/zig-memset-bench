const std = @import("std");

const cache_bench_files = [_][]const u8{
    "rpkak_aligned_cached",
    "rpkak_aligned_uncached",
    "rpkak_unaligned_cached",
    "rpkak_unaligned_uncached",
    "skk64_aligned_cached",
    "skk64_aligned_uncached",
    "skk64_unaligned_cached",
    "skk64_unaligned_uncached",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "memset_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                // .{ .name = "memset_bench", .module = mod },
            },
        }),
    });

    const obj = b.addObject(.{
        .name = "other_memsets",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/other_memsets.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });

    inline for (cache_bench_files) |f| {
        const exe2 = b.addExecutable(.{
            .name = f,
            .root_module = b.createModule(.{
                .root_source_file = b.path("bench2/" ++ f ++ ".zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    // .{ .name = "memset_bench", .module = mod },
                },
            }),
        });
        exe2.root_module.addObject(obj);
        b.installArtifact(exe2);
    }

    exe.root_module.addObject(obj);
    exe.root_module.link_libc = true;
    switch (target.result.cpu.arch) {
        .x86_64 => {
            exe.root_module.addAssemblyFile(b.path("src/musl_memset_x86_64.s"));
            exe.root_module.addAssemblyFile(b.path("src/glibc/memset-avx2-unaligned-erms.S"));
            exe.root_module.addAssemblyFile(b.path("src/glibc/memset-avx512-unaligned-erms.S"));
            // exe.root_module.addAssemblyFile(b.path("src/glibc/memset-avx512-no-vzeroupper.S"));
        },
        .aarch64 => {
            // this doesn't compile and I don't know why; it's compied straight from
            // musl source
            // exe.root_module.addAssemblyFile(b.path("src/musl_memset_aarch64.s"));
            // this needs extra header files that I'll need to modify
            // exe.root_module.addAssemblyFile(b.path("src/glibc/memset_sve_zva64.S"));
        },
        else => {},
    }

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
