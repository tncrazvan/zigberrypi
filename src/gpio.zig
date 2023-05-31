const std = @import("std");
const string = @import("string.zig").string;
const fs = std.fs;
const fmt = std.fmt;

const Direction = enum(u8) {
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
    const fileName = try string("{s}/sys/class/gpio/export", .{prefix});
    const createdFile = try fs.createFileAbsolute(fileName, .{});
    createdFile.close();
    const flags = .{ .mode = fs.File.OpenMode.write_only };
    const file = try fs.openFileAbsolute(fileName, flags);
    defer file.close();
    const slice = try string("{}", .{pin});
    _ = try file.write(slice);
}

/// Set the `direction` of the `pin`.
/// The `prefix` exists only for testing purposes.
fn setDirection(pin: u8, direction: Direction, prefix: []const u8) !void {
    const cwd = fs.cwd();
    const dirName = try string("{s}/sys/class/gpio/gpio{}", .{ prefix, pin });
    try cwd.makePath(dirName);
    const fileName = try string("{s}/direction", .{dirName});
    const createdFile = try fs.createFileAbsolute(fileName, .{});
    createdFile.close();
    const flags = .{ .mode = fs.File.OpenMode.write_only };
    const file = try fs.openFileAbsolute(fileName, flags);
    _ = try file.write(if (direction == Direction.Inward) "in" else "out");
    file.close();
}

/// Open a stream to a `pin`.
/// The `prefix` exists only for testing purposes.
/// TODO: test this.
fn open(pin: Pin, direction: Direction, prefix: []const u8) !GPIO {
    const upin = @enumToInt(pin);
    try setExport(upin, prefix);
    try setDirection(upin, direction, prefix);
    const fileName = try string("{s}/sys/class/gpio/gpio{}/value", .{ prefix, upin });
    const createdFile = try fs.createFileAbsolute(fileName, .{});
    createdFile.close();
    const flags = .{ .mode = if (direction == Direction.Inward) fs.File.OpenMode.read_only else fs.File.OpenMode.write_only };
    const file = try fs.openFileAbsolute(fileName, flags);

    return GPIO{ .file = file, .direction = direction, .pin = pin };
}
/// Open a stream to a pin in order to write to it.
pub fn openWritable(pin: Pin) !GPIO {
    return open(pin, Direction.Outward, "");
}
/// Open a stream to a pin in order to read from it.
pub fn openRead(pin: Pin) !GPIO {
    return open(pin, Direction.Inward, "");
}

const GPIOWritingError = error{PinIsNotWritable} | fs.File.WriteError;
const GPIOReadingError = error{PinIsNotReadable} | fs.File.ReadError;

const GPIO = struct {
    file: fs.File,
    direction: Direction,
    pin: Pin,
    /// Returns `true` if the pin is writable, `false` otherwise.
    pub fn isWritable(self: GPIO) bool {
        return self.direction == Direction.Outward;
    }
    /// Write data to the pin.
    pub fn write(self: GPIO, bytes: []const u8) !void {
        if (!self.isWritable()) {
            return GPIOWritingError;
        }
        _ = try self.file.write(bytes);
    }
    pub fn read(self: GPIO) ![]const u8 {
        if (self.isWritable()) {
            return GPIOReadingError;
        }
        const readerBuffer = []const u8{};
        _ = try self.file.read(readerBuffer);
        return readerBuffer;
    }
    /// Close the GPIO stream.
    pub fn close(self: GPIO) void {
        self.file.close();
    }
};
