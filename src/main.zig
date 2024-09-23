const std = @import("std");
const Allocator = std.mem.Allocator;
const windows = @import("windows/windows.zig");
const c = @cImport({
    @cInclude("MinHook.h");
});

const func_send_packet_raw = 0xDD2DD0;
var original_send_send_packet_raw: @TypeOf(&sendPacketRaw) = undefined;

pub fn main() !void {

    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //defer _ = gpa.deinit();

    //const allocator = gpa.allocator();

    const module_info = try windows.GetModuleInformation(windows.GetCurrentProcess(), try windows.GetModuleHandleA(null));
    const address = try getSendPacketRawAddress(module_info);

    try patchIntegrityCheck(module_info);

    if (c.MH_Initialize() != c.MH_OK) {
        return error.MinHookInitialize;
    }
    defer _ = c.MH_Uninitialize();

    // removing consts
    if (c.MH_CreateHook(@as(*anyopaque, @ptrFromInt(address)), @ptrFromInt(@intFromPtr(&sendPacketRaw)), @ptrFromInt(@intFromPtr(&original_send_send_packet_raw))) != c.MH_OK) {
        return error.MinHookCreateHook;
    }

    defer _ = c.MH_RemoveHook(c.MH_ALL_HOOKS);

    const status = c.MH_EnableHook(c.MH_ALL_HOOKS);
    if (status != c.MH_OK) {
        std.debug.print("{s}\n", .{c.MH_StatusToString(status)}); // todo add like trys
        return error.MinHokkEnableHook;
    }
    defer _ = c.MH_DisableHook(c.MH_ALL_HOOKS);

    std.debug.print("Hooked\n", .{});

    while (true) {
        std.Thread.yield() catch unreachable;
    }

    //std.debug.print("found address: 0x{X} base: 0x{X}\n", .{ address, address - @as(usize, @intFromPtr(module_info.lpBaseOfDll)) });

    //const base_address: usize = @intFromPtr(module_info.lpBaseOfDll);
    //const base_address_size = base_address + module_info.SizeOfImage;
    return error.Freeze;
}

fn patchIntegrityCheck(module_info: windows.MODULEINFO) !void {
    const address = findPattern(module_info, "3B C1 73 04 85 C9", 2) orelse return error.NotFound;
    try patchBytes(address, "90 90");
}

fn patchBytes(address: usize, comptime bytes_str: []const u8) !void {
    const bytes = comptime stringToBytes(bytes_str);
    const dest = @as([*]u8, @ptrFromInt(address));

    var old_protect: windows.DWORD = undefined;

    try windows.VirtualProtect(dest, bytes.len, windows.PAGE_EXECUTE_READWRITE, &old_protect);

    @memcpy(dest[0..bytes.len], bytes);

    return windows.VirtualProtect(dest, bytes.len, old_protect, &old_protect);
}

fn countStringToBytes(comptime pattern: []const u8) usize {
    var cnt = 0;
    const bytes = comptime patternToBytes(pattern);
    for (bytes) |b| {
        if (b != -1) {
            cnt += 1;
        }
    }
    return cnt;
}

fn stringToBytes(comptime pattern: []const u8) *const [countStringToBytes(pattern)]u8 {
    comptime {
        var result: [countStringToBytes(pattern)]u8 = undefined;
        var result_len = 0;

        const bytes = patternToBytes(pattern);
        for (bytes) |b| {
            if (b != -1) {
                result[result_len] = @intCast(b);
                result_len += 1;
            }
        }

        const final = result;
        return &final;
    }
}

fn sendPacketRaw(packet_type: i32, packet_data: *anyopaque, packet_len: u32, unknown: *anyopaque, peer: *anyopaque, flags: u32) callconv(.C) void {
    std.debug.print("sending packet\n", .{});
    return original_send_send_packet_raw(packet_type, packet_data, packet_len, unknown, peer, flags);
}

fn getSendPacketRawAddress(module_info: windows.MODULEINFO) !usize {
    // we can add like if runtimecheks
    const start: usize = @intFromPtr(module_info.lpBaseOfDll);
    //_ = start;
    //if (findPattern(module_info, "7e ? 8b 95 a0", 0)) |address| {
    // getting bad alignment loop by byte?
    //const a: u16 = @as(*u16, @alignCast(@as(*u16, @ptrFromInt(address - 2)))).*;
    //return address;
    //}
    //return error.NotFound;
    return start + func_send_packet_raw;
}

fn findPattern(module_info: windows.MODULEINFO, comptime pattern: []const u8, offset: u16) ?usize {
    const start: usize = @intFromPtr(module_info.lpBaseOfDll);
    const end = start + module_info.SizeOfImage;

    const bytes = comptime patternToBytes(pattern);

    // simd can do some stuff here?? is we can derefrence with simd
    for (start..end) |i| {
        for (0..bytes.len) |j| {
            if (@as(*u8, @ptrFromInt(i + j)).* != bytes[j] and bytes[j] != -1) {
                break;
            }

            if (j == bytes.len - 1) return i + offset;
        }
    }

    return null;
}
// i32 so we could tell if byte is null
// we can do this without allocations we can use comptime, we can make buffer size of patterns length
//
//

fn count(comptime pattern: []const u8) usize {
    var bytes: usize = 0;

    var i: usize = 0;
    inline while (i < pattern.len) {
        while (pattern[i] == ' ' and i < pattern.len) : (i += 1) {}
        if (pattern[i] == '?') {
            bytes += 1;
            i += 2;
            continue;
        }

        const len = std.mem.indexOfScalar(u8, pattern[i..], ' ') orelse pattern[i..].len;

        if (len == 0) {
            break;
        }

        bytes += 1;
        i += len;
    }
    return bytes;
}

fn patternToBytes(comptime pattern: []const u8) *const [count(pattern)]i32 {
    comptime {
        var bytes: [count(pattern)]i32 = undefined;
        var bytes_len: usize = 0;

        var i: usize = 0;
        while (i < pattern.len) {
            while (pattern[i] == ' ' and i < pattern.len) : (i += 1) {}
            if (pattern[i] == '?') {
                bytes[bytes_len] = -1;
                bytes_len += 1;

                i += 2;
                continue;
            }

            const len = std.mem.indexOfScalar(u8, pattern[i..], ' ') orelse pattern[i..].len;
            if (len == 0) {
                break;
            }

            bytes[bytes_len] = std.fmt.parseInt(i32, pattern[i .. i + len], 16) catch unreachable;
            bytes_len += 1;

            i += len;
        }

        const final = bytes;
        return &final;
    }
}

fn getCPPStr(address: usize) [:0]const u8 {
    const length = @as(*usize, @ptrFromInt(address + 0x10)).*;

    if (length == 0) return "";
    if (length > 15) {
        const str = @as(*[*:0]u8, @ptrFromInt(address)).*;
        return std.mem.span(str);
    }

    return std.mem.span(@as([*:0]u8, @ptrFromInt(address)));
}
