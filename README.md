# zigberrypi
Zig library for interacting with raspberrypi's gpio

## How to install

- add dependency
  ```sh
  zigmod aq install 1/tncrazvan/zigberrypi
  ```
- add a reference for the dependency in `build.zig`
  ```zig
  const deps = @import("deps.zig");
  // ...
  pub fn build(b: *std.Build) void {
  // ...
    deps.addAllTo(exe);
  // ...
  }
  ```
- import `zigberrypi` in your project with
   ```zig
   const gpio = @import("zigberrypi");
   ```

## Example

Blinking led example

```zig
const std = @import("std");
const gpio = @import("zigberrypi");

fn sleepForTwoSeconds() void {
    std.time.sleep(std.time.ns_per_s * 2);
}

pub fn main() !void {
    var active = false;
    const pin11 = try gpio.openWritable(gpio.Pin.PIN11);
    defer pin11.close();
    while (true) {
        try pin11.write(if (active) "1" else "0");
        active = !active;
        sleepForTwoSeconds();
    }
}
```
