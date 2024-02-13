const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "sokol-zig-microui-example",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });
    exe.root_module.addImport("sokol", dep_sokol.module("sokol"));
    exe.addIncludePath(.{.path = "lib",});
    exe.addCSourceFile(.{
        .file = .{ .path = "lib/microui.c" },
        .flags = &.{
            "-std=c99",
            "-fno-sanitize=undefined",
        },
    });

    exe.linkLibC();

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    b.step("run", "Run mysapp").dependOn(&run_cmd.step);
}

