# Review: rebelancap's iOS ports — what he built, what he didn't, and what an iPad-first MK64 can truthfully claim

Reviewed 2026-07-28 against the live GitHub API and raw file contents. This supplements [spaghettikart-ios-feasibility.md](spaghettikart-ios-feasibility.md): the hard-stop finding there ("someone shipped first") stands, but this review evaluates the *reframed* premise — a Mario Kart 64 port built **for iPad**, with real distribution — against what actually exists.

---

## 1. Reach: shipped, but never shared

The strongest fact in your favor. As of 2026-07-28:

| Repo | Stars | Forks | Watchers | IPA downloads |
|---|---|---|---|---|
| SpaghettiKart-ios | 1 | 0 | 0 | iOS: **1**, visionOS: **0** |
| Shipwright-ios | 0 | 0 | 0 | iOS: 2, visionOS: 2 |
| Starship-ios | 0 | 0 | 0 | 1 + 1 |
| 2ship2harkinian-ios | 0 | 0 | 0 | 1 + 1 |
| Ghostship-ios | 0 | 0 | 0 | 1 + 1 |
| harbourmasters-ports (SideStore source) | 0 | 0 | 0 | — |
| Sunset-Dawn mirror | 6 | 0 | 1 | (archive) |

- Zero open issues, discussions disabled, across the entire fleet. No user has ever engaged.
- Web/Reddit search finds **no announcement anywhere** — no Reddit thread, no X post, no listing in any community SideStore source index. The only external trace of "rebelancap" found online is a visionOS crash fix contributed to the [Apollo](https://github.com/Balackburn/Apollo/releases) Reddit client. The single-digit download counts corroborate: nobody knows these exist.
- The [Sunset-Dawn mirror](https://github.com/rebelancap/HarbourMasters-Sunset-Dawn-iOS-Ports) is **archived by design** ("Community mirror for preservation purposes") with a banner redirecting to his new ports. Its 6 stars are the only organic traction anything of his has.

Read: he is a builder, not a distributor. These ports are functionally private. "First to actually reach players" is an open position — but see §5, because zero traction also carries an unflattering market signal.

## 2. Correction: the touch controls are real, and they're good on paper

The claim "he didn't build touch controls for them at all" **does not survive the code**. Every one of the five README feature lists claims touch controls with a layout customizer, and for SpaghettiKart I verified the implementation directly ([app/ios/SohIosShell.m](https://github.com/rebelancap/SpaghettiKart-ios/blob/main/app/ios/SohIosShell.m), 3,338 lines):

- Floating analog stick (stick base set where the finger lands) — `SohIosShell.m:1338`
- **Kart-specific input design**: gas hold ≥0.6 s locks throttle on (haptic confirms), tap unlocks (`:2090-2101`); brake overrides locked gas *without* untoggling it, gas resumes on release (`:2114-2116`); item button distinguishes tap = native throw vs hold = carry (`:2127-2133`)
- Layout customizer with edit mode: drag any button, scale 70–140%, left-handed mirror, opacity CVar, per-button hide/show with eye badges, haptics off/light/strong (`:1365-1373`, `:1400`, `:1494`, `:1788-1790`, `:2004-2006`)

Do not position against "no touch controls" — that claim dies on first contact with the repo. Position against what is actually missing (§3).

## 3. What is actually missing

1. **iPad, entirely.** In 3,338 lines of shell there are **zero** occurrences of `iPad`, `userInterfaceIdiom`, or any idiom/size-class branch. The Requirements line reads "**iPhone on iOS 15+, or Apple Vision Pro (visionOS 2+)**" — iPad is not in it. Every screenshot is Vision Pro. Every title reads "for iPhone & Apple Vision Pro." iPad appears only in the SideStore-source table and the iloader line — i.e., "it will probably install," nothing more. The layout is a phone layout that has never been designed, tuned, or (as far as any evidence shows) tested on an iPad.
2. **Multiplayer — MK64's entire reason to exist on a tablet.** Upstream SpaghettiKart ships full split-screen support: `SCREEN_MODE_2P_SPLITSCREEN_HORIZONTAL`, `_VERTICAL`, and `SCREEN_MODE_3P_4P_SPLITSCREEN`, selectable in the menus (`HarbourMasters/SpaghettiKart:src/menus.c:96-98,1334-1338`). His README's word count on multiplayer, players, or split-screen: **zero**. Nobody has shipped 2–4 player split-screen Mario Kart 64 on one iPad with multiple controllers. That is the headline feature an iPad version can own.
3. **Tilt steering.** No CoreMotion anywhere in his feature list. Natural for a kart racer, absent from every prior port.
4. **Distribution beyond a dead-drop.** SideStore source + GitHub releases with no announcement is a filing cabinet, not distribution. No TestFlight, no AltStore PAL, no community presence, no install video, no support channel (issues unused, no Discord of his own — the README even routes crash reports to "GitHub issue or Discord" without saying which Discord).
5. **License clarity.** His README carries an unresolved TODO: "pick a license for this repo's own code (the app shell + overlay patches)." Treat his shell/patches as read-only reference, not reusable code, until that resolves.

## 4. What we could truthfully say (and what we couldn't)

Claims that are **true today** and defensible:

| Claim | Basis |
|---|---|
| "The first Mario Kart 64 **built for iPad**" | No prior port has a single line of iPad-specific code; both prior efforts are iPhone/Vision Pro-branded (Sunset-Dawn's release notes described sizing for "small iPhone screens") |
| "Split-screen Mario Kart on one iPad — 2 to 4 players, real controllers" | Upstream supports it (`menus.c:96-98`); no iOS port exposes or mentions it. **Must be built and validated for perf first** |
| "Tilt steering" | Absent from all prior ports. Must be built |
| "A grip-first iPad layout, not a scaled-up phone overlay" | HarkinianPad's proven design language vs. his idiom-free phone layout |
| "Actually released to the community" | True the day you post it anywhere at all — the bar is on the floor |
| "Tested on a physical iPad" | HarkinianPad already runs this playbook; his ports show no iPad evidence |

Claims to **avoid** because they are false or unverifiable:

- ~~"First Mario Kart 64 on iPhone/iOS"~~ — Sunset-Dawn shipped `1.0.0-E` (mirrored, downloadable), rebelancap shipped v1.0.0 on 2026-07-26.
- ~~"The existing ports have no touch controls"~~ — §2.
- ~~"The existing ports don't run on iPad"~~ — unverified; they likely install and render. Say "not designed for iPad," which is provable.

## 5. Honest risks

1. **He ships terrifyingly fast.** The fleet history shows five polished ports released in one day on a shared 47-patch stack, plus Quake ×3, sm64coopdx, and a visionOS iloader fork inside a month. Adding an idiom check and iPad screenshots is a weekend for him. Differentiation has to be the stuff that takes real design and hardware work — split-screen multiplayer, tilt, a genuinely designed iPad layout, and community presence — not "runs on iPad."
2. **Zero traction cuts both ways.** His downloads are 1–2 per IPA partly because he never shared them — but also, sideloaded N64 ports are a niche behind a real friction wall (SideStore/iloader/7-day resigning). "We'll share it" is necessary, not sufficient. The audience thesis should be tested with a HarkinianPad-style post before betting months on it.
3. **His work makes yours easier and the claim window shorter.** The 47 patches are a public, current map of every LUS/SpaghettiKart iOS fix plus performance work (async Metal shaders, texture-cache eviction, supersampling) — enormously useful as *reference* (license caveat in §3.5), and equally available to anyone else who finds it.
4. **Nintendo exposure is unchanged** from the feasibility doc, and Mario is the most-defended franchise. A port that gets attention (the goal) also gets more exposure than one nobody downloads.
5. **Upstream is an alternative lane.** coco875's draft PR [#694](https://github.com/HarbourMasters/SpaghettiKart/pull/694) is stalled since May; nothing iOS has merged into HarbourMasters mainline. Landing official iOS/iPadOS support upstream is a position neither Sunset-Dawn nor rebelancap took, and it outlives any fork.

## 6. Bottom line

The feasibility verdict's premise — "first SpaghettiKart on iOS" — is dead and stays dead. The reframed premise — **"the first Mario Kart 64 actually made for iPad: grip-designed touch controls, split-screen multiplayer with real controllers, tilt steering, and a release people can actually find"** — is factually open on every point. Nobody has done any of it, including him. The competition is one unpromoted developer whose branding, requirements, screenshots, and code all say iPhone + Vision Pro, whose ports have single-digit downloads, and who has never posted about them anywhere findable.

If that premise is adopted, the next step is a fresh Stage 1 gate against it: sideload his v1.0.0 on the iPad Pro and characterize exactly how it behaves there (rendering, layout, controllers, extraction), and validate split-screen perf assumptions on device — before any implementation planning.

---

## 7. The "first time on iPad" claim — exact truth boundaries

Analysis added 2026-07-28 for the LinkedIn-post question.

**What is technically true:** rebelancap's IPA *is* a native iPad build target. His build config sets `XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"` (`overlay/patches/0013-spaghetti-cmake-ios-app-target.patch:200`) with landscape-only orientations and `UIRequiresFullScreen`; the released IPA's `Info.plist` confirms `UIDeviceFamily [1,2]`, `MinimumOSVersion 16.4` (verified by direct inspection, 2026-07-28). Sunset-Dawn's mirrored `SpaghettiKart-iOS-1.0.0-E.ipa` was also inspected: `UIDeviceFamily [1,2]`, `MinimumOSVersion 13.0`, bundle id `com.harbourmasters.spaghettikart`, plus template-boilerplate `UISupportedInterfaceOrientations~ipad` entries (including portrait — no kart game runs in portrait; this is scaffold, not design). Both IPAs are ROM-free (bundled `spaghetti.o2r` port archive + `yamls/` extraction descriptors only). So on an iPad, **both** prior binaries would install and run full-screen as iPad apps, not letterboxed. A strict claim of the form "Mario Kart 64 *could not* run natively on iPad before" is therefore false — iPad-capable binaries have existed publicly since at least 2026-07-01 (mirror) and were built as early as June 2026.

**What has zero public counter-evidence:** no screenshot, video, post, article, or forum thread anywhere findable shows Mario Kart 64 running natively on an iPad. rebelancap's own materials never show or claim an iPad run: requirements say "iPhone on iOS 15+, or Apple Vision Pro," every screenshot is Vision Pro, the shell has no iPad-specific code, and the iOS IPA has one download. All press coverage of SpaghettiKart (LinuxAdictos, GamingOnLinux, RetroRGB, PCGamingWiki) lists PC/Linux/Mac/Steam Deck/Switch only. Emulators (Delta et al.) run MK64 on iPad, but that is emulation — the word "natively" excludes it and must stay in any claim.

**Claim tiers:**

| Tier | Wording | Status |
|---|---|---|
| Bulletproof | "The first Mario Kart 64 **built for iPad**" / "with touch controls designed for iPad" | Provable from public record; no asterisk |
| Bulletproof | "Split-screen Mario Kart 64 on one iPad — this has never existed on any Apple device" | No prior port mentions multiplayer at all; nothing to dispute (must be built first) |
| Defensible | "As far as I can find, the first time Mario Kart 64 has ever run natively on an iPad" | No public counter-evidence exists; the only possible disputant has never posted anything and his own docs say iPhone/Vision Pro. Same latent-prior-art shape the viral OoT post already survived (Sunset-Dawn's Shipwright IPA predated it, mirrored publicly since 2026-07-01) |
| False | "MK64 couldn't run on iPad before" / "no one has made MK64 for iOS" | His device-family-2 IPA exists; two iOS ports shipped |

**Note on the OoT precedent:** the viral HarkinianPad post carried the same hidden asterisk — an OoT iOS IPA (Sunset-Dawn's `Shipwright-iOS-9.2.3-I`) existed before it, publicly mirrored — and nobody surfaced to dispute it. The dynamics here are identical, with one difference: the prior art is now *known*, so the honest hedge ("as far as I can find") or the built-for-iPad framing is the right call — it keeps the post true even if someone does the archaeology, and the comeback ("that one was an iPhone/Vision Pro app that happens to install on iPad — this is the first one *made* for iPad") strengthens rather than weakens the story.
