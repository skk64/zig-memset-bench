const std = @import("std");

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
    exe.root_module.link_libc = true;
    switch (target.result.cpu.arch) {
        .x86_64 => {
            exe.root_module.addAssemblyFile(b.path("src/musl_memset_x86_64.s"));
            exe.root_module.addAssemblyFile(b.path("src/glibc/memset-avx2-unaligned-erms.S"));
            exe.root_module.addAssemblyFile(b.path("src/glibc/memset-avx512-unaligned-erms.S"));
        },
        .aarch64 => {
            // exe.root_module.addAssemblyFile(b.path("src/musl_memset_aarch64.s"));
            // exe.root_module.addAssemblyFile(b.path("src/glibc/memset_sve_zva64.S"));
        },
        else => {},
    }

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
