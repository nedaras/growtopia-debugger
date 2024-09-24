const std = @import("std");
const Allocator = std.mem.Allocator;
const windows = @import("windows/windows.zig");
const c = @cImport({
    @cInclude("MinHook.h");
});

const func_send_packet_raw = 0xDD2DD0;
const func_send_packet = 0xDD2AE0;
const func_http_finish = 0x81B950; // this address is way off but in a good direction after wa are able to debug http requests organize this mess

var original_send_send_packet_raw: @TypeOf(&sendPacketRaw) = undefined;
var original_send_send_packet: @TypeOf(&sendPacket) = undefined;
var original_http_request: @TypeOf(&http_request) = undefined;

pub fn main() !void {

    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //defer _ = gpa.deinit();

    //const allocator = gpa.allocator();

    const module_info = try windows.GetModuleInformation(windows.GetCurrentProcess(), try windows.GetModuleHandleA(null));
    const base: usize = @intFromPtr(module_info.lpBaseOfDll);

    try patchIntegrityCheck(module_info);

    if (c.MH_Initialize() != c.MH_OK) {
        return error.MinHookInitialize;
    }
    defer _ = c.MH_Uninitialize();

    // removing consts
    if (c.MH_CreateHook(@as(*anyopaque, @ptrFromInt(base + func_send_packet_raw)), @ptrFromInt(@intFromPtr(&sendPacketRaw)), @ptrFromInt(@intFromPtr(&original_send_send_packet_raw))) != c.MH_OK) {
        return error.MinHookCreateHook;
    }

    if (c.MH_CreateHook(@as(*anyopaque, @ptrFromInt(base + func_send_packet)), @ptrFromInt(@intFromPtr(&sendPacket)), @ptrFromInt(@intFromPtr(&original_send_send_packet))) != c.MH_OK) {
        return error.MinHookCreateHook;
    }

    if (c.MH_CreateHook(@as(*anyopaque, @ptrFromInt(base + func_http_finish)), @ptrFromInt(@intFromPtr(&http_request)), @ptrFromInt(@intFromPtr(&original_http_request))) != c.MH_OK) {
        return error.MinHookCreateHook;
    }
    defer _ = c.MH_RemoveHook(c.MH_ALL_HOOKS);

    if (c.MH_EnableHook(c.MH_ALL_HOOKS) != c.MH_OK) {
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

const vec2f_t = extern struct {
    x: f32,
    y: f32,
};

const game_packet_type = enum(u8) {
    state,
    call_function,
    update_status,
    tile_change_request,
    send_map_data,
    send_tile_update_data,
    send_tile_update_data_multiple,
    tile_activate_reque0x140811580st,
    tile_apply_damage,
    send_inventory_state,
    item_activate_request,
    item_activate_object_request,
    send_tile_tree_state,
    modify_item_inventory,
    item_change_object,
    send_lock,
    send_item_database_data,
    send_particle_effect,
    set_icon_state,
    item_effect,
    set_character_state,
    ping_reply,
    ping_request,
    got_punched,
    app_check_response,
    app_integrity_fail,
    disconnect,
    battle_join,
    battle_event,
    use_door,
    send_parental,
    gone_fishin,
    steam,
    pet_battle,
    npc,
    special,
    send_particle_effect_v2,
    active_arrow_to_item,
    select_tile_index,
    send_player_tribute_data,
    ftue_set_item_to_quick_inventory,
    pve_npc,
    pvpcard_battle,
    pve_apply_player_damage,
    pve_npc_position_update,
    set_extra_mods,
    on_step_on_tile_mod,
};

const game_packet_t = extern struct {
    type: game_packet_type,
    object_type: u8,
    byte2: u8,
    byte3: u8,
    netid: i32,
    item: i32,
    flags: u32,
    float1: f32,
    int3: i32,
    vec1: vec2f_t,
    vec2: vec2f_t,
    float2: f32,
    tile_x: i32, // block_x when unused its prob always -1
    tile_y: i32, // block_y when unused its prob always -1
    extra_data_size: u32, // never got this
};

var packet_cnt: usize = 0;

fn debugRawPacket(packet: game_packet_t) void {
    defer packet_cnt += 1;
    std.debug.print("const game_packet_t({d}) = extern struct {s}\n", .{ packet_cnt, "{" });
    std.debug.print("    type: {s},\n", .{@tagName(packet.type)});
    if (packet.object_type != 0) std.debug.print("    object_type: {d},\n", .{packet.object_type});
    if (packet.byte2 != 0) std.debug.print("    byte2: {d},\n", .{packet.byte2});
    if (packet.byte3 != 0) std.debug.print("    byte3: {d},\n", .{packet.byte3});
    if (packet.netid != 0) std.debug.print("    netid: {d},\n", .{packet.netid});
    if (packet.item != 0) std.debug.print("    item: {d},\n", .{packet.item});
    if (packet.flags != 0) std.debug.print("    flags: {b:0>32},\n", .{packet.flags});
    if (packet.float1 != 0) std.debug.print("    floats1: {d},\n", .{packet.float1});
    if (packet.int3 != 0) std.debug.print("    int3: {d},\n", .{packet.int3});
    if (packet.vec1.x != 0 or packet.vec1.y != 0) std.debug.print("    vec1: ({d}, {d}),\n", .{ packet.vec1.x, packet.vec1.y });
    if (packet.vec2.x != 0 or packet.vec2.y != 0) std.debug.print("    vec2: ({d}, {d}),\n", .{ packet.vec2.x, packet.vec2.y });
    if (packet.float2 != 0) std.debug.print("    floats2: {d},\n", .{packet.float2});
    if (packet.tile_x != 0) std.debug.print("    tile_x: {d},\n", .{packet.tile_x});
    if (packet.tile_y != 0) std.debug.print("    tile_y: {d},\n", .{packet.tile_y});
    if (packet.extra_data_size != 0) std.debug.print("    extra_data_size: {d},\n", .{packet.extra_data_size});
    std.debug.print("{s};\n", .{"}"});
}

fn sendPacketRaw(packet_type: i32, packet: *game_packet_t, packet_len: u32, unknown: *anyopaque, peer: *anyopaque, flags: u32) callconv(.C) void {
    debugRawPacket(packet.*);
    return original_send_send_packet_raw(packet_type, packet, packet_len, unknown, peer, flags);
}

fn sendPacket(packet_type: i32, cpp_str: *anyopaque, peer: *anyopaque) callconv(.C) void {
    const data = getCPPStr(@intFromPtr(cpp_str));
    //std.debug.print("sending packet type: {d}, data:\n{s}\n", .{ packet_type, data });
    std.debug.print("\nsending packet type: {d}, data:\n'{s}'\n", .{ packet_type, data });
    return original_send_send_packet(packet_type, cpp_str, peer);
}

fn http_request(a1: *anyopaque) callconv(.C) *anyopaque {
    // idk wtf is this prob hooking wrong stuff its void
    const ret = original_http_request(a1);
    std.debug.print("have http request 0x{X}, ret: 0x{X}\n", .{ @intFromPtr(a1), @intFromPtr(ret) });
    return ret;
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
