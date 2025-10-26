const build_script = @embedFile("./scripts/build.sh");
const std = @import("std");
const make_index = @import("make_index");
const package = @import("package");
const fetch = @import("fetch");

pub fn make(allocator: std.mem.Allocator, file: []const u8) !void {
    const package_info = try make_index.create_package(allocator, file);
    defer allocator.destroy(package_info);
    // install_dependencies(allocator, &package_info.depend) catch |err| switch (err) {
    //     error.InstallFailed => std.log.err("Failed to install packages", .{}),
    //     else => {
    //         std.debug.print("Unknown Error: {any}\n", .{err});
    //         std.process.exit(33);
    //     },
    // };

    if (!exists("/etc/hburg/build.sh")) {
        _ = try makeDirAbsoluteRecursive(allocator, "/etc/hburg/");
        var file_sh = try std.fs.createFileAbsolute("/etc/hburg/build.sh", .{});
        defer file_sh.close();

        try file_sh.writeAll(build_script);
    }

    const hashfile = try std.fmt.allocPrint(allocator, "{s}.hash", .{file});
    defer allocator.free(hashfile);

    if (exists(hashfile)) {
        std.debug.print("delete old .hash file\n", .{});
        try std.fs.cwd().deleteFile(hashfile);
    }
    build_package(allocator, file, package_info.*) catch |err| {
        std.debug.print("Failed to build package: {any}\n", .{err});
        std.process.exit(1);
    };

    packaging(allocator, file, package_info.*) catch |err| {
        std.debug.print("Failed to package package: {any}\n", .{err});
        std.process.exit(1);
    };
}

fn install_dependencies(allocator: std.mem.Allocator, packages: *const [64][32]u8) !void {
    var packages_slice: [64][]const u8 = undefined;
    var count: usize = 0;

    for (packages) |pkg| {
        const name = std.mem.trim(u8, &pkg, " \n\r\t\x00");

        if (name.len == 0) continue;

        packages_slice[count] = name;
        count += 1;
    }

    const packages_joined = try std.mem.join(allocator, " ", packages_slice[0..count]);
    defer allocator.free(packages_joined);

    var child = std.process.Child.init(&.{
        "/usr/bin/hclos",
        "install",
        packages_joined,
    }, allocator);

    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    child.stdin_behavior = .Ignore;

    const result = try child.spawnAndWait();

    if (result != .Exited or result.Exited != 0) {
        std.log.err("Failed to install packages\n", .{});
        return error.InstallFailed;
    }
}

fn build_package(allocator: std.mem.Allocator, hb_file: []const u8, package_info: package.Package) !void {
    std.debug.print("fetch: {s}", .{package_info.src_url});

    const name = std.mem.sliceTo(&package_info.name, 0);
    const version = std.mem.sliceTo(&package_info.version, 0);

    const source_dir = "/var/lib/hburg/build/";

    const source_file = try std.fmt.allocPrint(allocator, "{s}/src-{s}-{s}", .{ source_dir, name, version });
    defer allocator.free(source_file);

    _ = try makeDirAbsoluteRecursive(allocator, source_dir);
    try fetch_source(allocator, &package_info.src_url, source_file);
    // defer deleteTreeAbsolute(source_file);

    std.debug.print("\r\x1b[2Kbuilding: {s}\n", .{package_info.name});

    const package_dir = try std.fmt.allocPrint(allocator, "/var/lib/hburg/build/packaging-{s}", .{name});
    defer allocator.free(package_dir);

    const build_dir = try std.fmt.allocPrint(allocator, "/var/lib/hburg/build/build-{s}", .{name});
    defer allocator.free(build_dir);

    const build_file = try std.fs.realpathAlloc(allocator, hb_file);
    defer allocator.free(build_file);

    _ = try makeDirAbsoluteRecursive(allocator, package_dir);

    _ = try makeDirAbsoluteRecursive(allocator, build_dir);

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    try env_map.put("PACKAGE_DIR", package_dir);
    try env_map.put("SOURCE_FILE", source_file);
    try env_map.put("BUILD_DIR", build_dir);
    try env_map.put("BUILD_FILE", build_file);

    var child = std.process.Child.init(&.{
        "/usr/bin/env",
        "sh",
        "-c",
        ". /etc/hburg/build.sh; build_package",
    }, allocator);

    child.env_map = &env_map;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    child.stdin_behavior = .Inherit;

    const result = try child.spawnAndWait();

    if (result != .Exited or result.Exited != 0) {
        std.log.err("Failed to build package", .{});
        return error.BuildFailed;
    }

    std.debug.print("build done\n", .{});
}

fn packaging(allocator: std.mem.Allocator, file: []const u8, package_info: package.Package) !void {
    const name = std.mem.sliceTo(&package_info.name, 0);
    const version = std.mem.sliceTo(&package_info.version, 0);

    const source_dir = "/var/lib/hburg/build/";

    const source_file = try std.fmt.allocPrint(allocator, "{s}/src-{s}-{s}", .{ source_dir, name, version });

    const package_dir = try std.fmt.allocPrint(allocator, "/var/lib/hburg/build/packaging-{s}/", .{name});
    defer allocator.free(package_dir);
    defer deleteTreeAbsolute(package_dir);

    const build_dir = try std.fmt.allocPrint(allocator, "/var/lib/hburg/build/build-{s}", .{name});
    defer allocator.free(build_dir);
    defer deleteTreeAbsolute(build_dir);

    const build_file = try std.fs.realpathAlloc(allocator, file);
    defer allocator.free(build_file);

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    try env_map.put("PACKAGE_DIR", package_dir);
    try env_map.put("SOURCE_FILE", source_file);
    try env_map.put("BUILD_DIR", build_dir);
    try env_map.put("BUILD_FILE", build_file);
    std.debug.print("\r\x1b[2Kpackage(): {s}", .{package_info.name});

    {
        var child = std.process.Child.init(&.{
            "/usr/bin/env",
            "sh",
            "-c",
            ". /etc/hburg/build.sh; packaging_package",
        }, allocator);

        child.env_map = &env_map;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
        child.stdin_behavior = .Inherit;

        const result = try child.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            std.log.err("Failed to packaging package\n", .{});
            return error.BuildFailed;
        }
    }

    std.debug.print("\r\x1b[2Kcompressing: {s}", .{name});
    const output = try std.fmt.allocPrint(allocator, "{s}.hcl", .{name});
    defer allocator.free(output);
    _ = try std.fs.cwd().createFile(output, .{});

    const realpath = try std.fs.realpathAlloc(allocator, output);

    {
        const tar_cmd = try std.fmt.allocPrint(allocator, "cd {s} && tar -cjf {s} .", .{ package_dir, realpath });
        defer allocator.free(tar_cmd);

        var child = std.process.Child.init(&.{
            "/usr/bin/env",
            "sh",
            "-c",
            tar_cmd,
        }, allocator);

        child.env_map = &env_map;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Pipe;
        child.stdin_behavior = .Inherit;

        const result = try child.spawnAndWait();

        if (child.stderr) |err| {
            const readed = try err.deprecatedReader().readAllAlloc(allocator, 4096);
            std.debug.print("\x1b[s\x1b[1A\n{s}\n", .{readed});
            std.debug.print("\x1b[u", .{});
        }

        if (result != .Exited or result.Exited != 0) {
            return error.BuildFailed;
        }
    }
    std.debug.print("\n", .{});
}

fn fetch_source(alc: std.mem.Allocator, url: []const u8, save_file: []const u8) !void {
    const url_z = try alc.dupeZ(u8, url);
    defer alc.free(url_z);

    const save_file_path = std.mem.sliceTo(save_file, 0);
    var file = try std.fs.createFileAbsolute(save_file_path, .{});
    defer file.close();

    try fetch.fetch_file(url_z, &file);
}

pub fn makeDirAbsoluteRecursive(allocator: std.mem.Allocator, dir_path: []const u8) !void {
    var parts = std.mem.splitSequence(u8, dir_path, "/");
    var current_path = std.ArrayList(u8){};
    defer current_path.deinit(allocator);

    if (dir_path.len > 0 and dir_path[0] == '/') {
        try current_path.append(allocator, '/');
    }

    while (parts.next()) |part| {
        if (part.len == 0) continue;

        if (current_path.items.len > 1) {
            try current_path.append(allocator, '/');
        }
        try current_path.appendSlice(allocator, part);

        std.fs.makeDirAbsolute(current_path.items) catch |err| {
            if (err != error.PathAlreadyExists) {
                return err;
            }
        };
    }
}

fn exists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

fn deleteTreeAbsolute(file: []const u8) void {
    std.fs.deleteTreeAbsolute(file) catch |err| {
        std.log.err("Failed to delete directory: {any}\n", .{err});
    };
}
