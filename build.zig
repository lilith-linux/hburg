const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .musl,
    });
    const optimize = b.standardOptimizeOption(.{});

    // for zig-toml
    const dep_toml = b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    });

    // ========== MODULES ===========
    const constants = b.addModule("constants", .{
        .root_source_file = b.path("src/constants.zig"),
        .target = target,
    });

    const info = b.addModule("info", .{
        .root_source_file = b.path("src/info.zig"),
        .target = target,
    });

    const repos_conf = b.addModule("repos_conf", .{ .root_source_file = b.path("src/repos_conf.zig"), .target = target, .imports = &.{
        .{ .name = "constants", .module = constants },
    } });
    repos_conf.addImport("toml", dep_toml.module("toml"));

    const package = b.addModule("package", .{
        .root_source_file = b.path("src/package/package.zig"),
        .target = target,
    });

    const writer = b.addModule("writer", .{ .root_source_file = b.path("src/package/writer/writer.zig"), .target = target, .imports = &.{
        .{ .name = "package", .module = package },
    } });

    const reader = b.addModule("reader", .{ .root_source_file = b.path("src/package/reader/reader.zig"), .target = target, .imports = &.{
        .{ .name = "package", .module = package },
    } });

    const make_index = b.addModule("make_index", .{ .root_source_file = b.path("src/build/make_index.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "constants", .module = constants },
        .{ .name = "info", .module = info },
        .{ .name = "package", .module = package },
        .{ .name = "reader", .module = reader },
        .{ .name = "writer", .module = writer },
    } });

    const build_indexes = b.addModule("build", .{
        .root_source_file = b.path("src/build/build.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "constants", .module = constants },
            .{ .name = "info", .module = info },
            .{ .name = "package", .module = package },
            .{ .name = "reader", .module = reader },
            .{ .name = "writer", .module = writer },
            .{ .name = "make_index", .module = make_index },
        },
    });

    const exe = b.addExecutable(.{
        .name = "hburg",
        .linkage = .static,
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize, .imports = &.{
            .{ .name = "constants", .module = constants },
            .{ .name = "info", .module = info },
            .{ .name = "repos_conf", .module = repos_conf },
            .{ .name = "reader", .module = reader },
            .{ .name = "writer", .module = writer },
            .{ .name = "package", .module = package },
            .{ .name = "build", .module = build_indexes },
            .{ .name = "make_index", .module = make_index },
        } }),
    });

    // imports
    exe.root_module.addImport("toml", dep_toml.module("toml"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
