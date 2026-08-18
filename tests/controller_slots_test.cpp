#include "SpaghettiPadControllerSlots.h"

#include <cassert>
#include <cstdint>
#include <vector>

struct FakeInput {
    uint32_t buttons = 0;
    int16_t leftX = 0;
    int16_t leftY = 0;
    int16_t rightX = 0;
    int16_t rightY = 0;
    int16_t leftTrigger = 0;
    int16_t rightTrigger = 0;
};

static FakeInput ReadPlayer(const SpaghettiPadControllerSlots& slots, size_t player,
                            const std::vector<std::pair<int32_t, FakeInput>>& connected) {
    int32_t wanted = slots.InstanceForSlot(player);
    for (const auto& [instanceId, input] : connected) {
        if (instanceId == wanted) {
            return input;
        }
    }
    return {};
}

static bool IsNeutral(const FakeInput& input) {
    return input.buttons == 0 && input.leftX == 0 && input.leftY == 0 && input.rightX == 0 && input.rightY == 0 &&
           input.leftTrigger == 0 && input.rightTrigger == 0;
}

int main() {
    SpaghettiPadControllerSlots slots;

    assert(slots.Assign(101) == 0);
    FakeInput held{ 0xFFFF, 25000, -25000, 18000, -18000, 32767, 32767 };
    assert(!IsNeutral(ReadPlayer(slots, 0, { { 101, held } })));
    auto released = slots.ReleaseMissing({});
    assert(released.size() == 1 && released[0].first == 0 && released[0].second == 101);
    assert(slots.InstanceForSlot(0) == SpaghettiPadControllerSlots::kUnassigned);
    assert(IsNeutral(ReadPlayer(slots, 0, {})));

    assert(slots.Assign(202) == 0);
    assert(slots.Assign(303) == 1);
    assert(slots.InstanceForSlot(0) == 202);
    assert(slots.InstanceForSlot(1) == 303);

    released = slots.ReleaseMissing({ 202 });
    assert(released.size() == 1 && released[0].first == 1 && released[0].second == 303);
    assert(slots.InstanceForSlot(0) == 202);
    assert(slots.Assign(404) == 1);
    assert(slots.InstanceForSlot(0) == 202);
    assert(slots.InstanceForSlot(1) == 404);

    released = slots.ReleaseMissing({ 404 });
    assert(released.size() == 1 && released[0].first == 0 && released[0].second == 202);
    assert(slots.InstanceForSlot(1) == 404);
    assert(IsNeutral(ReadPlayer(slots, 0, { { 404, held } })));

    return 0;
}
