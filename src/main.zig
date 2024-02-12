const std = @import("std");
const mem = std.mem;
const bufPrint = std.fmt.bufPrint;

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sgl = sokol.gl;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;

const as = @import("atlas.zig");
const cc = as.cc;
const atlas = as.atlas;
const r = @import("renderer.zig");
const itof = r.itof;

const Font = cc.mu_Font;
var ctx_obj = mem.zeroes(cc.mu_Context);
const ctx: *cc.mu_Context = &ctx_obj;

const Logbuf = getLogbufType(64000);
var logbuf: Logbuf = undefined;
var logbuf_updated = false;
fn getLogbufType(comptime n: usize) type {
    return struct {
        const This = @This();
        buf: []u8 = undefined,
        size: usize = n,
        pub fn init(this: *This, allocator: std.mem.Allocator) !void {
            const ptr = try allocator.alloc(u8, this.size);
            @memset(ptr, 0);
            this.buf = @as([]u8, ptr);
        }
        pub fn deinit(_:*This) void {
        }
    };
}

const Arena = std.heap.ArenaAllocator;
var arena: Arena = undefined;

const Color = struct{r:f32=0, g:f32=0, b:f32=0, a:f32=0};
var bg: Color = .{
    .r = 90.0, .g = 95.0, .b = 100.0
};
pub inline fn ftoi(t: type, f: f32) t {
    return @as(t, @intFromFloat(f));
}
pub fn text_width_cb(_: Font, text: [*c]const u8, len: c_int) callconv(.C) c_int {
    var ret: c_int =
        if(len == -1) @intCast(mem.len(text))
        else len; _ = &ret;
    return r.get_text_width(text, ret);
}

pub fn text_height_cb(_: Font) callconv(.C) c_int {
    return r.get_text_height();
}

pub fn write_log(text: [:0]const u8) void {
    if(logbuf.buf[0] != 0) {
        _ = cc.strcat(logbuf.buf.ptr, "\n");
    }
    _ = cc.strcat(logbuf.buf.ptr, text);
    logbuf_updated = true;
}

var pass_action: sg.PassAction = .{};
export fn init() void {
    sg.setup(.{
        .context = sgapp.context(),
        .logger = .{ .func = slog.func },
    });
    pass_action.colors[0] = .{
        .load_action = .CLEAR,
    };
    sgl.setup(.{
        .logger = .{ .func = slog.func },
    });

    r.init(arena.allocator()) catch { @panic("renderer init error"); };

    cc.mu_init(ctx);
    ctx.text_width = text_width_cb;
    ctx.text_height = text_height_cb;
}

const key_map = T_T: {
    var ret = [_]u8{0} ** 512;
    ret[@intFromEnum(sapp.Keycode.LEFT_SHIFT)] = cc.MU_KEY_SHIFT;
    ret[@intFromEnum(sapp.Keycode.RIGHT_SHIFT)] = cc.MU_KEY_SHIFT;
    ret[@intFromEnum(sapp.Keycode.LEFT_CONTROL)] = cc.MU_KEY_CTRL;
    ret[@intFromEnum(sapp.Keycode.RIGHT_CONTROL)] = cc.MU_KEY_CTRL;
    ret[@intFromEnum(sapp.Keycode.LEFT_ALT)] = cc.MU_KEY_ALT;
    ret[@intFromEnum(sapp.Keycode.RIGHT_ALT)] = cc.MU_KEY_ALT;
    ret[@intFromEnum(sapp.Keycode.ENTER)] = cc.MU_KEY_RETURN;
    ret[@intFromEnum(sapp.Keycode.BACKSPACE)] = cc.MU_KEY_BACKSPACE;
    break :T_T ret;
};

inline fn getKey(k: sapp.Keycode) u8 {
    return key_map[@intCast(@intFromEnum(k) & 511)];
}
export fn event(eve: ?*const sapp.Event) void {
    const ev = eve.?;
    switch(ev.type) {
        .MOUSE_DOWN => {
            _ = cc.mu_input_mousedown(ctx,
                @intFromFloat(ev.mouse_x),
                @intFromFloat(ev.mouse_y),
                @as(c_int, 1) << @intCast(@intFromEnum(ev.mouse_button)),);
        },
        .MOUSE_UP => {
            _ = cc.mu_input_mouseup(ctx,
                @intFromFloat(ev.mouse_x),
                @intFromFloat(ev.mouse_y),
                @as(c_int, 1) << @intCast(@intFromEnum(ev.mouse_button)),);
        },
        .MOUSE_MOVE => {
            _ = cc.mu_input_mousemove(ctx,
                @intFromFloat(ev.mouse_x),
                @intFromFloat(ev.mouse_y),
                );
        },
        .MOUSE_SCROLL => {
            _ = cc.mu_input_scroll(ctx, 0, @intFromFloat(ev.scroll_y));
        },
        .KEY_DOWN => {
            if (ev.key_code == .ESCAPE) {
                sapp.requestQuit();
            }
            _ = cc.mu_input_keydown(ctx, getKey(ev.key_code));
        },
        .KEY_UP => {
            _ = cc.mu_input_keyup(ctx, getKey(ev.key_code));
        },
        .CHAR => {
            if(ev.char_code != 127) {
                var txt:[2:0]u8 = .{@intCast(ev.char_code & 0xFF),0};
                cc.mu_input_text(ctx, &txt);
            }
        },
        else => {},
    }
}

export fn frame() void {
    cc.mu_begin(ctx);
    test_window(ctx);
    log_window(ctx);
    style_window(ctx);
    cc.mu_end(ctx);

    r.begin(sapp.width(), sapp.height());
    var cmd: ?*cc.mu_Command = null;
    while(cc.mu_next_command(ctx, @ptrCast(&cmd)) != 0) {
        switch(cmd.?.type) {
            cc.MU_COMMAND_TEXT =>
                r.draw_text(&cmd.?.text.str, cmd.?.text.pos, cmd.?.text.color),
            cc.MU_COMMAND_RECT =>
                r.draw_rect(cmd.?.rect.rect, cmd.?.rect.color),
            cc.MU_COMMAND_ICON =>
                r.draw_icon(cmd.?.icon.id, cmd.?.icon.rect, cmd.?.icon.color),
            cc.MU_COMMAND_CLIP =>
                r.set_clip_rect(cmd.?.clip.rect),
            else => {},
        }
    }
    r.end();

    pass_action.colors[0] = .{
        .load_action = sg.LoadAction.CLEAR,
        .clear_value = .{.r=bg.r/255.0, .g=bg.g/255.0, .b=bg.b/255.0, .a=1.0},
    };
    sg.beginDefaultPass(pass_action, sapp.width(), sapp.height());
    r.draw();
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sgl.shutdown();
    sg.shutdown();
}

const Tmp = struct {
    var buf = [_]u8{0} ** 128;
};
fn getBuf() @TypeOf(&Tmp.buf) {
    return (&Tmp.buf);
}
var checks = [_]i32{1,0,1};
fn test_window(_: *cc.mu_Context) void {
    if(cc.mu_begin_window(ctx, "Demo Window", cc.mu_rect(40,40,300,450)) != 0) {
        var win: *cc.mu_Container = cc.mu_get_current_container(ctx);
        win.rect.w = @max(win.rect.w, 240);
        win.rect.h = @max(win.rect.h, 300);

        if(cc.mu_header(ctx, "Window Info")!=0) {
            var win2: *cc.mu_Container = cc.mu_get_current_container(ctx); _ = &win2;
            var buf = getBuf();
            cc.mu_layout_row(ctx, 2, &[_]i32{54,-1}, 0);
            cc.mu_label(ctx, "Position:");
            _ = bufPrint(buf, "{}, {}",.{win2.rect.x, win2.rect.y}) catch {}; cc.mu_label(ctx, buf[0..]);
            cc.mu_label(ctx, "Size:");
            _ = bufPrint(buf, "{}, {}",.{win2.rect.x, win2.rect.y}) catch {}; cc.mu_label(ctx, buf[0..]);

        }
        if(cc.mu_header_ex(ctx, "Test Buttons", cc.MU_OPT_EXPANDED)!=0) {
            cc.mu_layout_row(ctx, 2, &[_]i32{86,-110, -1}, 0);
            cc.mu_label(ctx, "Test buttons 1:");
            if(cc.mu_button(ctx, "Button 1:")!=0) write_log("Press button 1");
            if(cc.mu_button(ctx, "Button 2:")!=0) write_log("Press button 2");
            cc.mu_label(ctx, "Test buttons 2:");
            if(cc.mu_button(ctx, "Button 3:")!=0) write_log("Press button 3");
            if(cc.mu_button(ctx, "Popup:")!=0) cc.mu_open_popup(ctx, "Test Popup");
            if(cc.mu_begin_popup(ctx, "Test Popup")!=0) {
                _ = cc.mu_button(ctx, "Hello");
                _ = cc.mu_button(ctx, "World");
                cc.mu_end_popup(ctx);
            }
        }

        if(cc.mu_header_ex(ctx, "Tree and Text", cc.MU_OPT_EXPANDED)!=0) {
            cc.mu_layout_row(ctx, 2, &[_]i32{140, -1}, 0);
            cc.mu_layout_begin_column(ctx);
            if(cc.mu_begin_treenode(ctx, "Test 1")!=0) {
                if(cc.mu_begin_treenode(ctx, "Test 1a")!=0) {
                    cc.mu_label(ctx, "Hello");
                    cc.mu_label(ctx, "world");
                    cc.mu_end_treenode(ctx);
                }
                if(cc.mu_begin_treenode(ctx, "Test 1b")!=0) {
                    if(cc.mu_button(ctx, "Button 1")!=0) write_log("Pressed button 1");
                    if(cc.mu_button(ctx, "Button 2")!=0) write_log("Pressed button 2");
                    cc.mu_end_treenode(ctx);
                }
                cc.mu_end_treenode(ctx);
            }
            if(cc.mu_begin_treenode(ctx, "Test 2")!=0) {
                cc.mu_layout_row(ctx, 2, &[_]i32{54,54}, 0);
                if(cc.mu_button(ctx, "Button 3")!=0) write_log("Pressed button 3");
                if(cc.mu_button(ctx, "Button 4")!=0) write_log("Pressed button 4");
                if(cc.mu_button(ctx, "Button 5")!=0) write_log("Pressed button 5");
                if(cc.mu_button(ctx, "Button 6")!=0) write_log("Pressed button 6");
                cc.mu_end_treenode(ctx);
            }
            if(cc.mu_begin_treenode(ctx, "Test 3")!=0) {
                _ = cc.mu_checkbox(ctx, "Checkbox 1", &checks[0]);
                _ = cc.mu_checkbox(ctx, "Checkbox 2", &checks[1]);
                _ = cc.mu_checkbox(ctx, "Checkbox 3", &checks[2]);
                cc.mu_end_treenode(ctx);
            }
            cc.mu_layout_end_column(ctx);

            cc.mu_layout_begin_column(ctx);
            cc.mu_layout_row(ctx, 1, &[_]i32{-1}, 0);
            cc.mu_text(ctx,
                \\Lorem ipsum dolor sit amet, consectetur adipiscing
                \\elit. Maecenas lacinia, sem eu lacinia molestie, mi risus faucibus
                \\ipsum, eu varius magna felis a nulla.
            );
            cc.mu_layout_end_column(ctx);
        }

        if(cc.mu_header_ex(ctx, "Background Color", cc.MU_OPT_EXPANDED)!=0) {
            cc.mu_layout_row(ctx, 2, &[_]i32{-78,-1}, 74);

            cc.mu_layout_begin_column(ctx);
            cc.mu_layout_row(ctx, 2, &[_]i32{46,-1}, 0);
            cc.mu_label(ctx, "Red:"); _ = cc.mu_slider(ctx, &bg.r, 0, 255);
            cc.mu_label(ctx, "Green:"); _ = cc.mu_slider(ctx, &bg.g, 0, 255);
            cc.mu_label(ctx, "Blue:"); _ = cc.mu_slider(ctx, &bg.b, 0, 255);
            cc.mu_layout_end_column(ctx);

            const rt: cc.mu_Rect = cc.mu_layout_next(ctx);
            cc.mu_draw_rect(ctx, rt, cc.mu_color(@intFromFloat(bg.r), @intFromFloat(bg.g), @intFromFloat(bg.b), 255));
            var buf = [_]u8{0} ** 32;
            _ = bufPrint(&buf, "#{X:0>2}{X:0>2}{X:0>2}", .{ftoi(u8,bg.r),ftoi(u8,bg.g),ftoi(u8,bg.b)}) catch {};
            cc.mu_draw_control_text(ctx, &buf, rt, cc.MU_COLOR_TEXT, cc.MU_OPT_ALIGNCENTER);
        }

        cc.mu_end_window(ctx);
    }
}

fn log_window(_: *cc.mu_Context) void {
    if(cc.mu_begin_window(ctx, "Log Window", cc.mu_rect(350,40,300,200)) != 0) {
        cc.mu_layout_row(ctx, 1, &[_]i32{-1}, -25);
        cc.mu_begin_panel(ctx, "Log Output");
        var panel: *cc.mu_Container = cc.mu_get_current_container(ctx);
        cc.mu_layout_row(ctx, 1, &[_]i32{-1}, -1);
        cc.mu_text(ctx, logbuf.buf.ptr);
        cc.mu_end_panel(ctx);
        if(logbuf_updated) {
            panel.scroll.y = panel.content_size.y;
            logbuf_updated = false;
        }

        var buf = getBuf();
        var submitted = false;
        cc.mu_layout_row(ctx, 2, &[_]i32{-70,-1}, 0);
        if((cc.mu_textbox(ctx, buf, buf.len) & cc.MU_RES_SUBMIT)!=0) {
            cc.mu_set_focus(ctx, ctx.last_id);
            submitted = true;
        }
        if(cc.mu_button(ctx, "Submit")!=0) submitted = true;
        if(submitted) {
            write_log(@ptrCast(buf));
            buf[0] = 0;
        }
        cc.mu_end_window(ctx);
    }
}

pub fn u8_slider(value: *u8, low: i32, high: i32) void {
    var tmp: f32 = 0;
    //_ = &low; _ = &high; _=&value; _=&tmp;
    cc.mu_push_id(ctx, @ptrCast(&value), @sizeOf(cc.mu_Real));
    tmp = itof(value.*);
    _ = cc.mu_slider_ex(ctx, &tmp, itof(low), itof(high), 0, "%.0f", cc.MU_OPT_ALIGNCENTER);
    value.* = @as(u8,(@intFromFloat(tmp)));
    cc.mu_pop_id(ctx);
}
var colors = [_]struct{label:[:0]const u8="", idx: i32=0}   {
    .{ .label="test",          .idx=cc.MU_COLOR_TEXT        },
    .{ .label="border:",       .idx=cc.MU_COLOR_BORDER      },
    .{ .label="windowbg:",     .idx=cc.MU_COLOR_WINDOWBG    },
    .{ .label="titlebg:",      .idx=cc.MU_COLOR_TITLEBG     },
    .{ .label="titletext:",    .idx=cc.MU_COLOR_TITLETEXT   },
    .{ .label="panelbg:",      .idx=cc.MU_COLOR_PANELBG     },
    .{ .label="button:",       .idx=cc.MU_COLOR_BUTTON      },
    .{ .label="buttonhover:",  .idx=cc.MU_COLOR_BUTTONHOVER },
    .{ .label="buttonfocus:",  .idx=cc.MU_COLOR_BUTTONFOCUS },
    .{ .label="base:",         .idx=cc.MU_COLOR_BASE        },
    .{ .label="basehover:",    .idx=cc.MU_COLOR_BASEHOVER   },
    .{ .label="basefocus:",    .idx=cc.MU_COLOR_BASEFOCUS   },
    .{ .label="scrollbase:",   .idx=cc.MU_COLOR_SCROLLBASE  },
    .{ .label="scrollthumb:",  .idx=cc.MU_COLOR_SCROLLTHUMB },
};
fn style_window(_: *cc.mu_Context) void {
    if(cc.mu_begin_window(ctx, "Style Editor", cc.mu_rect(350,250,300,240))!=0) {
        const ter: *cc.mu_Container = cc.mu_get_current_container(ctx);
        const sw: i32 = ftoi(i32, itof(ter.body.w) * 0.14);
        cc.mu_layout_row(ctx, 6, &[_]i32{80,sw,sw,sw,sw,-1}, 0);
        for(0..colors.len)|i| {
            cc.mu_label(ctx, colors[i].label);
            u8_slider(&ctx.style.*.colors[i].r, 0, 255);
            u8_slider(&ctx.style.*.colors[i].g, 0, 255);
            u8_slider(&ctx.style.*.colors[i].b, 0, 255);
            u8_slider(&ctx.style.*.colors[i].a, 0, 255);
            cc.mu_draw_rect(ctx, cc.mu_layout_next(ctx), ctx.*.style.*.colors[i]);
        }
        cc.mu_end_window(ctx);
    }
}

pub fn main() void {
    arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();

    logbuf = Logbuf{};
    logbuf.init(arena.allocator()) catch {
        @panic("logbuf init error");
    };

    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .width = 720,
        .height = 540,
        .icon = .{
            .sokol_default = true,
        },
        .window_title = "mui-sokol-zig example",
        .logger = .{
            .func = slog.func,
        },
        //.win32_console_attach = true,
    });
}

