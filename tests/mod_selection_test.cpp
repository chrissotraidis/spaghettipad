#include "ModSelection.h"
#include <cassert>
#include <iostream>
using namespace SpaghettiPadMods;
int main() {
    Resources hd, npc, link, kris, ralsei, musicA, musicB;
    hd.Add("textures/tracks/luigi_raceway/road.png");
    hd.Add("textures/karts/luigi_kart/frame000_wheel0.png");
    npc.Add("textures/karts/luigi_kart/frame001_wheel1.png");
    npc.Add("textures/karts/yoshi_kart/frame000_wheel0.png");
    npc.Add("textures/karts/toad_kart/frame000_wheel0.png");
    link.Add("textures/karts/luigi_kart/frame000_wheel0.png");
    kris.Add("textures/karts/yoshi_kart/frame001_wheel0.png");
    ralsei.Add("textures/karts/toad_kart/frame001_wheel0.png");
    assert(!Conflict(hd, npc) && !Conflict(npc, hd));
    assert(!Conflict(hd, link));
    assert(Conflict(npc, link) && Conflict(npc, kris) && Conflict(npc, ralsei));
    assert(!Conflict(link, kris) && !Conflict(kris, ralsei));
    assert(Conflict(hd, hd));
    musicA.Add("sound/sequences/main_menu.mp3");
    musicB.Add("sound/sequences/main_menu.ogg.json");
    assert(Conflict(musicA, musicB));
    assert(!Conflict(npc, musicA));
    assert(ResourceKey("mods.toml").empty());
    assert(ResourceKey("README.txt").empty());
    assert(SettingKey("a.b.o2r") != SettingKey("a/b.o2r"));
    assert(SettingKey("Link.o2r") == SettingKey("Link.o2r"));
    std::cout << "Mod selection conflict regression passed.\n";
}
