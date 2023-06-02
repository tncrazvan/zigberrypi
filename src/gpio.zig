const std = @import("std");
const string = @import("string.zig").string;
const fs = std.fs;
const fmt = std.fmt;
const page = std.heap.page_allocator;
const expect = std.testing.expect;

pub const Direction = enum(u8) {
    /// Use this to read from the header.
    Inward = 0,
    /// Use this to write to the header.
    Outward = 1,
};

pub const Pin = enum(u8) {
    PIN7 = 4,
    PIN11 = 17,
    PIN12 = 18,
    PIN13v1 = 21,
    PIN13v2 = 27,
    PIN15 = 22,
    PIN16 = 23,
    PIN18 = 24,
    PIN22 = 25,
};

/// Export the `pin` allowing it to be written to and read from.
/// The `prefix` exists only for testing purposes.
fn setExport(pin: u8, prefix: []const u8) !void {
    const cwd = fs.cwd();
    try cwd.makePath(try string("{s}/sys/class/gpio", .{prefix}));
    const file_name = try string("{s}/sys/class/gpio/export", .{prefix});
    const created_file = try fs.createFileAbsolute(file_name, .{});
    created_file.close();
    const flags = .{ .mode = fs.File.OpenMode.write_only };
    const file = try fs.openFileAbsolute(file_name, flags);
    defer file.close();
    const slice = try string("{}", .{pin});
    _ = try file.write(slice);
}

/// Set the `direction` of the `pin`.
/// The `prefix` exists only for testing purposes.
fn setDirection(pin: u8, direction: Direction, prefix: []const u8) !void {
    const cwd = fs.cwd();
    const dir_name = try string("{s}/sys/class/gpio/gpio{}", .{ prefix, pin });
    try cwd.makePath(dir_name);
    const file_name = try string("{s}/direction", .{dir_name});
    const created_file = try fs.createFileAbsolute(file_name, .{});
    created_file.close();
    const flags = .{ .mode = fs.File.OpenMode.write_only };
    const file = try fs.openFileAbsolute(file_name, flags);
    _ = try file.write(if (direction == Direction.Inward) "in" else "out");
    file.close();
}

/// Open a stream to a `pin`.
/// The `prefix` exists only for testing purposes.
fn open(pin: Pin, direction: Direction, prefix: []const u8) !GPIO {
    const upin = @enumToInt(pin);
    try setExport(upin, prefix);
    try setDirection(upin, direction, prefix);
    const file_name = try string("{s}/sys/class/gpio/gpio{}/value", .{ prefix, upin });
    const created_file = try fs.createFileAbsolute(file_name, .{});
    created_file.close();
    const flags = .{ .mode = if (direction == Direction.Inward) fs.File.OpenMode.read_only else fs.File.OpenMode.write_only };
    const file = try fs.openFileAbsolute(file_name, flags);

    return GPIO{ .file = file, .direction = direction, .pin = pin, .file_name = file_name };
}

test "writable pin" {
    const path_prefix = "./.zigberrypi.testing.out";
    try std.fs.cwd().makePath(path_prefix);
    const full_prefix = try std.fs.cwd().realpathAlloc(std.heap.page_allocator, path_prefix);
    const gpio = try open(Pin.PIN11, Direction.Outward, full_prefix);
    defer gpio.close();
    _ = try gpio.write("test");
    const file = try fs.openFileAbsolute(gpio.file_name, .{});
    defer file.close();
    const contents = try file.readToEndAlloc(page, 4);
    try expect(std.mem.eql(u8, "test", contents));
}

test "readable pin" {
    const path_prefix = "./.zigberrypi.testing.out";
    try std.fs.cwd().makePath(path_prefix);
    const full_prefix = try std.fs.cwd().realpathAlloc(std.heap.page_allocator, path_prefix);
    const gpio = try open(Pin.PIN12, Direction.Outward, full_prefix);
    defer gpio.close();

    const file = try fs.openFileAbsolute(gpio.file_name, .{});
    defer file.close();

    _ = try gpio.write("test");

    const contents = try file.readToEndAlloc(page, 4);
    try expect(std.mem.eql(u8, "test", contents));
}

/// Open a stream to a pin in order to write to it.
pub fn openWritable(pin: Pin) !GPIO {
    return open(pin, Direction.Outward, "");
}
/// Open a stream to a pin in order to read from it.
pub fn openRead(pin: Pin) !GPIO {
    return open(pin, Direction.Inward, "");
}

const GPIO = struct {
    /// File used to read and write.
    file: fs.File,
    /// Diretion of the pin.
    direction: Direction,
    /// Number of the pin.
    pin: Pin,
    /// Name of the file providing the stream for the pin.
    file_name: []const u8,
    /// Returns `true` if the file stream is writable, `false` otherwise.
    pub fn isWritable(self: GPIO) bool {
        return self.direction == Direction.Outward;
    }
    /// Write data to the pin.
    pub fn write(self: GPIO, bytes: []const u8) !usize {
        if (!self.isWritable()) {
            return error.UnableToWriteToPin;
        }
        return try self.file.write(bytes);
    }
    /// Read data from the pin.
    pub fn read(self: GPIO) ![]u8 {
        if (self.isWritable()) {
            return error.UnableToReadFromPin;
        }
        return try self.file.readToEndAlloc(page, 1024);
    }
    /// Close the GPIO stream.
    pub fn close(self: GPIO) void {
        self.file.close();
    }
};
