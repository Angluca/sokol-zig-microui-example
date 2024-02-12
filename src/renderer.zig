const std = @import("std");
const as = @import("atlas.zig");
const atlas = as.atlas;
const cc = as.cc;
const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const sgl = sokol.gl;
const Arena = std.heap.ArenaAllocator;

var atlas_img: sg.Image = undefined;
var atlas_smp: sg.Sampler = undefined;
var pip: sgl.Pipeline = std.mem.zeroes(sgl.Pipeline);

const Rect = cc.mu_Rect;
const Color = cc.mu_Color;
const Vec2 = cc.mu_Vec2;

pub fn init(allocator: std.mem.Allocator) !void {
    const rgba8_size: u32 = as.width * as.height * 4;
    const rgba8_pixels = try allocator.alloc(u32, rgba8_size);
    for(0..as.height)|y| {
        for(0..as.width)|x| {
            const idx = y * as.width + x;
            rgba8_pixels[idx] = 0x00FFFFFF | (@as(u32, as.texture[idx]) << 24);
        }
    }
    var st = sg.ImageDesc {
        .width = as.width,
        .height = as.height,
    };
    st.data.subimage[0][0] = sg.Range {.ptr = @ptrCast(rgba8_pixels), .size = rgba8_size};
    atlas_img = sg.makeImage(st);

    atlas_smp = sg.makeSampler(sg.SamplerDesc {
        .min_filter = sg.Filter.NEAREST,
        .mag_filter = sg.Filter.NEAREST,
    });

    var pp = std.mem.zeroes(sg.PipelineDesc);
    pp.colors[0].blend = .{
        .enabled = true,
        .src_factor_rgb = sg.BlendFactor.SRC_ALPHA,
        .dst_factor_rgb = sg.BlendFactor.ONE_MINUS_SRC_ALPHA,
    };
    pip = sgl.makePipeline(pp);
}

pub fn begin(disp_width: i32, disp_height: i32) void {
    sgl.defaults();
    sgl.pushPipeline();
    sgl.loadPipeline(pip);
    sgl.enableTexture();
    sgl.texture(atlas_img, atlas_smp);
    sgl.matrixModeProjection();
    sgl.pushMatrix();
    sgl.ortho(0.0, @floatFromInt(disp_width), @floatFromInt(disp_height), 0.0, -1.0, 1.0);
    sgl.beginQuads();
}

pub fn end() void {
    sgl.end();
    sgl.popMatrix();
    sgl.popPipeline();
}

pub fn draw() void {
    sgl.draw();
}

pub inline fn itof(n: anytype) f32 {
    return @floatFromInt(n);
}
pub fn push_quad(dst: Rect, src:Rect, color: Color) void {
    const U0 = itof(src.x) / itof(as.width);
    const V0 = itof(src.y) / itof(as.height);
    const U1 = itof(src.x + src.w) / itof(as.width);
    const V1 = itof(src.y + src.h) / itof(as.height);

    const x0 = itof(dst.x);
    const y0 = itof(dst.y);
    const x1 = itof(dst.x + dst.w);
    const y1 = itof(dst.y + dst.h);

    sgl.c4b(color.r, color.g, color.b, color.a);
    sgl.v2fT2f(x0, y0, U0, V0);
    sgl.v2fT2f(x1, y0, U1, V0);
    sgl.v2fT2f(x1, y1, U1, V1);
    sgl.v2fT2f(x0, y1, U0, V1);
}

pub fn draw_rect(rect: Rect, color: Color) void {
    push_quad(rect, as.atlas[as.white], color);
}

pub fn draw_text(text: [*]const u8, pos: Vec2, color: Color) void {
    var dst = Rect {.x=pos.x, .y=pos.y, .w=0, .h=0};
    var i: u32 = 0;
    while(text[i] != 0):(i += 1) {
        const src = as.atlas[as.font + text[i]];
        dst.w = src.w;
        dst.h = src.h;
        push_quad(dst, src, color);
        dst.x += dst.w;
    }
}

pub fn draw_icon(id: i32, rect: Rect, color: Color) void {
    const src = atlas[@intCast(id)];
    const x = rect.x + @divTrunc((rect.w - src.w), 2);
    const y = rect.y + @divTrunc((rect.h - src.h), 2);
    push_quad(Rect{.x=x, .y=y, .w=src.w, .h=src.h}, src, color);
}

pub fn get_text_width(text: [*c]const u8, len:c_int) c_int {
    var res: c_int = 0;
    var i: u32 = 0;
    var idx:u32 = 0;
    while(text[i] != 0 and i < len):(i+=1) {
        idx = as.font + @as(u8,text[i]);
        res += @as(c_int, @intCast(as.atlas[idx].w));
    }
    return res;
}

pub fn get_text_height() c_int {
    return 18;
}

pub fn set_clip_rect(rect: Rect) void {
    sgl.end();
    sgl.scissorRect(rect.x, rect.y, rect.w, rect.h, true);
    sgl.beginQuads();
}
