const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;

pub fn build(b: *Build) !void {
    //std.fs.cwd().deleteTree("zig-cache") catch undefined;
    //if (b.args) |arg| {
        //if(std.mem.eql(u8, @as([*]const u8, @ptrCast(arg.ptr)), "clear")) {
            //std.fs.cwd().deleteTree("zig-cache") catch undefined;
            //std.debug.print("cache removed !\n", .{});
            //return;
        //}
        ////run_cmd.addArgs(args);
    //}


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

    //const task_step = b.step("clear", "clear cache");
    //task_step.makeFn = myTask;
    //b.default_step = task_step;
}

//fn myTask(self: *std.Build.Step, progress: *std.Progress.Node) !void {
    //std.fs.cwd().deleteTree("zig-cache") catch undefined;
    //std.debug.print("cache removed !\n", .{});
    //_ = progress;
    //_ = self;
//}
