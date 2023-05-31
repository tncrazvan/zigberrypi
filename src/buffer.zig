pub fn buffer(comptime size: u8) *[size]u8 {
    var resultingBuffer: [size]u8 = undefined;
    return &resultingBuffer;
}
