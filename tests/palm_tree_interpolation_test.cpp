#include <array>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <vector>
using s32 = int32_t;
using s16 = int16_t;
using f32 = float;
using Vec3f = float[3];
using Vec3s = int16_t[3];
using Mat4 = float[4][4];
struct Camera { Vec3f pos{}; Vec3s rot{}; float fieldOfView{}; };
struct UnkActorSpawnData { int16_t pos[3]; int16_t someId; };
Camera cameras[4];
Camera* camera1 = cameras;
UnkActorSpawnData spawns[4];
int gGamestate, gIsGamePaused, gMatrixObjectCount;
float gTrackDirection = 1;
constexpr int CREDITS_SEQUENCE = 1, END_OF_SPAWN_DATA = -32768, MTX_OBJECT_POOL_SIZE = 128;
int culledX = -1, noCulling = 0, depth = 0;
uintptr_t currentTag;
std::vector<std::pair<int, uintptr_t>> draws;
#define UNUSED
#define LOAD_ASSET(...) spawns
#define TAG_ITEM_ADDR(x) (uintptr_t(x))
#define gSPTexture(...)
#define gDPSetCombineMode(...)
#define gDPSetRenderMode(...)
#define gSPClearGeometryMode(...)
#define gSPDisplayList(...)
int CVarGetInteger(const char*, int) { return noCulling; }
float is_within_render_distance(const Vec3f, const Vec3f p, int, float, float, float) {
    return p[0] == culledX ? -1.0f : 1.0f;
}
void FrameInterpolation_RecordOpenChild(const char*, uintptr_t tag) {
    assert(depth++ == 0); currentTag = tag;
}
void FrameInterpolation_RecordCloseChild() { assert(--depth == 0); }
void mtxf_pos_rotation_xyz(Mat4 m, Vec3f p, Vec3s) {
    for (int i = 0; i < 3; ++i) m[3][i] = p[i];
}
void render_set_position(Mat4 m, int) {
    draws.emplace_back(int(m[3][0]), currentTag); ++gMatrixObjectCount;
}
#include "render_palm_trees_under_test.inc"
static auto render(int camera = 0) {
    Mat4 m{}; draws.clear(); depth = 0; gMatrixObjectCount = 0;
    render_palm_trees(&cameras[camera], m); assert(depth == 0); return draws;
}
int main() {
    spawns[0] = {{10, 0, 0}, 0}; spawns[1] = {{20, 0, 0}, 4};
    spawns[2] = {{30, 0, 0}, 6}; spawns[3] = {{END_OF_SPAWN_DATA, 0, 0}, 0};
    auto all = render(); assert(all.size() == 3);
    culledX = 10; auto culled = render(); assert(culled.size() == 2);
    if (culled[0] != all[1] || culled[1] != all[2]) {
        std::fprintf(stderr, "FAIL: culling an earlier tree changes another tree's interpolation identity\n"); return 1;
    }
    culledX = -1; spawns[0].someId |= 0x0800;
    auto hidden = render(); assert(hidden == culled);
    spawns[0].someId &= ~0x0800; assert(render() == all);
    for (int c = 1; c < 4; ++c) {
        auto other = render(c); assert(other.size() == all.size());
        for (size_t i = 0; i < all.size(); ++i) {
            assert(other[i].first == all[i].first);
            for (auto item : all) assert(other[i].second != item.second);
        }
    }
    culledX = 10; noCulling = 1; assert(render() == all);
    noCulling = 0; culledX = -1;
    Mat4 m{}; gMatrixObjectCount = MTX_OBJECT_POOL_SIZE; draws.clear();
    render_palm_trees(camera1, m); assert(draws.empty() && depth == 0);
    spawns[0].someId = 6; gMatrixObjectCount = MTX_OBJECT_POOL_SIZE;
    render_palm_trees(camera1, m); assert(draws.empty() && depth == 0);
    std::puts("Palm-tree interpolation identity regression passed.");
}
