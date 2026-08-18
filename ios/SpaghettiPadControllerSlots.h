#pragma once

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <utility>
#include <vector>

class SpaghettiPadControllerSlots {
  public:
    static constexpr size_t kPlayerCount = 4;
    static constexpr int32_t kUnassigned = -1;

    SpaghettiPadControllerSlots() {
        mSlots.fill(kUnassigned);
    }

    std::vector<std::pair<size_t, int32_t>> ReleaseMissing(const std::vector<int32_t>& connectedInstanceIds) {
        std::vector<std::pair<size_t, int32_t>> released;
        for (size_t slot = 0; slot < mSlots.size(); ++slot) {
            int32_t instanceId = mSlots[slot];
            if (instanceId != kUnassigned &&
                std::find(connectedInstanceIds.begin(), connectedInstanceIds.end(), instanceId) ==
                    connectedInstanceIds.end()) {
                released.emplace_back(slot, instanceId);
                mSlots[slot] = kUnassigned;
            }
        }
        return released;
    }

    std::optional<size_t> Assign(int32_t instanceId) {
        if (auto existing = SlotFor(instanceId); existing.has_value()) {
            return existing;
        }
        for (size_t slot = 0; slot < mSlots.size(); ++slot) {
            if (mSlots[slot] == kUnassigned) {
                mSlots[slot] = instanceId;
                return slot;
            }
        }
        return std::nullopt;
    }

    std::optional<size_t> SlotFor(int32_t instanceId) const {
        for (size_t slot = 0; slot < mSlots.size(); ++slot) {
            if (mSlots[slot] == instanceId) {
                return slot;
            }
        }
        return std::nullopt;
    }

    int32_t InstanceForSlot(size_t slot) const {
        return slot < mSlots.size() ? mSlots[slot] : kUnassigned;
    }

  private:
    std::array<int32_t, kPlayerCount> mSlots;
};
