# aigos — TestFlight QA Testing Guide

**Build under test:** 61 (bumped from 60 for the default-vehicle crash fix)
**Target OS:** iOS 17.0 → 26.x · iPhone only
**Build config:** Release (App Store), Xcode 26.6 / iOS 26.5 SDK
**App ID:** `6787352080` · bundle `com.aigos.app`

> aigos is **offline-first and privacy-first**. Almost every check below should be
> performed with **Wi-Fi and cellular OFF** to prove the core app never needs a
> network. The only online-only feature is the optional MapKit picker (§1.9).

---

## How to use this guide

1. Work top-to-bottom on a **physical iPhone** installed from TestFlight (the
   simulator can't exercise haptics, the custom tab bar taps, real Location, or
   TestFlight-signed behavior).
2. Mark each row **✅ pass / ❌ fail / ⚠️ partial**.
3. For every ❌ or ⚠️, file a bug using the **template in §6**.
4. Repeat the **P0 regression block (§0)** on at least two devices before sign-off.
5. Re-run §0 + any failed rows after each new build.

---

## §0. P0 regression block — DEFAULT VEHICLE (run first, every build)

The build-60 crash "app crashes when setting a vehicle as default" was fixed in
build 61 by routing **all** default changes through one safe path
(`VehicleProfile.setAsDefault(_:context:)` — fetch all → clear every `isDefault`
→ set the target → save once, wrapped in do/catch). Prove it holds:

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 0.1 | First vehicle becomes default | Fresh install → onboarding → add 1 vehicle | Vehicle is default (amber checkmark), no crash |
| 0.2 | Set default from **Settings** | Settings → Default vehicle → tap a non-default row | Selection moves, exactly one checkmark, no crash |
| 0.3 | Set default from **Garage picker** | Calculate → vehicle picker → long-press a row → "Set as Default" | Checkmark moves, no crash |
| 0.4 | Switch default back and forth rapidly | Toggle default A→B→A→B fast in Settings | Never two checkmarks, never a crash |
| 0.5 | Set default via **Add/Edit** toggle | Edit a vehicle → enable "Make default" → Save | That vehicle becomes the only default |
| 0.6 | New vehicle with "Make default" on | Add vehicle → toggle default ON → Save | New vehicle is the only default |
| 0.7 | **Delete the default** vehicle | Garage → swipe/left → Delete the default (with ≥1 other vehicle) | Next vehicle auto-promoted to default; trip history preserved; no crash |
| 0.8 | Delete a **non-default** vehicle | Delete a non-default vehicle | Default unchanged; no crash |
| 0.9 | Delete the **last** vehicle | Delete until zero vehicles | Empty-state shown, no crash, no orphaned default |
| 0.10 | Kill & relaunch after each change | Force-quit → reopen | Exactly one default persists across launches |

**Invariant to verify everywhere:** at any moment there is **exactly one**
default vehicle (or zero when the garage is empty) — never two checkmarks.

---

## §1. Complete feature checklist

### 1.1 Launch & onboarding
- [ ] Cold launch shows the static launch screen (gradient + mascot + wordmark) instantly, then the animated splash, then fades to the app.
- [ ] First launch: splash shows a **Get Started** CTA (not auto-advance).
- [ ] Onboarding is **4 steps**: 0 = welcome hero (large centered mascot, gentle float), 1 = add vehicle, 2 = driving, 3 = prices.
- [ ] Progress bar is **hidden on step 0**, visible on 1–3.
- [ ] Can't advance past "add vehicle" without a valid vehicle.
- [ ] Finishing onboarding lands on the **Calculate** tab.
- [ ] Returning user: splash auto-advances (~1.8s), no onboarding.

### 1.2 Tab bar & shell
- [ ] Custom floating pill tab bar shows 5 icon-only tabs: Calculate · History · Saved · Prices · Settings.
- [ ] Amber `matchedGeometry` indicator slides smoothly between tabs.
- [ ] Every feature is reachable in one tap (no deep nav stacks).
- [ ] Waving-mascot watermark appears subtly (bottom-trailing) on each of the 5 tab roots — **once**, not doubled on empty states.

### 1.3 Vehicles / garage
- [ ] Add vehicle: name, type, fuel type, efficiency (respects unit), optional year, maintenance status.
- [ ] Efficiency field reflects the current unit (km/L or L/100km) and converts correctly.
- [ ] Edit vehicle: "Edit Vehicle" title, "Save changes", pre-filled fields, default toggle.
- [ ] Swipe-left row → **Edit** (amber) and **Delete** (red) actions.
- [ ] Long-press row → context menu: Edit, Set as Default (only if not already default), Delete.
- [ ] Delete asks for confirmation; **preserves TripRecord history**.
- [ ] Amber **ring** = selected-for-calc; amber **checkmark** = default (distinct visuals).
- [ ] Tapping a row selects it for calculation and dismisses.

### 1.4 Calculate (core)
- [ ] Requires **both** origin AND destination chosen from the dropdown before Calculate enables.
- [ ] Random free-text (e.g. "J") does **not** validate as a place.
- [ ] `PlaceField` autocomplete: personal places first, then gazetteer, max 5, aliases work ("BGC", "EDSA", "QC").
- [ ] "How you'll drive" summary row shows a truncated one-liner and opens `DrivingSheet`.
- [ ] `DrivingSheet` sections: Speed, AC, Road type, Traffic (+ rush-hour), Passengers & load, Fuel level, Weather, Road surface. Bindings apply live; summary updates on dismiss.
- [ ] Calculate button: deep-brown pill with amber glow, idle pulse; disabled state dimmed (0.45).
- [ ] Tapping Calculate → spinner + "Calculating…" (light haptic) → after ≥1.2s reveals the result **sheet** (medium haptic).
- [ ] `ResultSheet`: route header, `ResultCard` receipt with 0→final count-up, "Save this route" + "Done".
- [ ] `ResultCard` shows the full breakdown: distance, base efficiency, each **driving factor** row, **vehicle factors** group (green gain / amber loss), adjusted efficiency, litres, PHP total.
- [ ] Currency renders as `PHP 261.43` (prefix), never the ₱ glyph.
- [ ] Low-fuel warning appears when the trip needs more fuel than the tank fraction holds (doesn't change cost).
- [ ] Swipe-down dismisses the result back to the form with values intact.

### 1.5 History
- [ ] Every calculation auto-saves a full `TripRecord` snapshot.
- [ ] Month-over-month comparison + stats render.
- [ ] Fuel-economy badge respects the current unit.
- [ ] Empty state shows text-only mascot empty state (no doubled mascot).

### 1.6 Saved routes
- [ ] "Save this route" from a result creates a `SavedRoute`.
- [ ] One-tap recalc from a saved route works and reflects current prices.
- [ ] Delete a saved route.

### 1.7 Prices
- [ ] All PH fuel types listed (unleaded91, premium95, premium97, diesel, premiumDiesel, eGasoline).
- [ ] Tap-to-edit inline rows; edits persist and feed the next calculation.
- [ ] Editing a price and returning to Calculate changes the computed total.

### 1.8 Settings
- [ ] Fuel-unit pills (km/L ↔ L/100km) are **real buttons** — tap reliably toggles (this was a fixed bug; verify by tapping directly on the pill).
- [ ] Unit change propagates **everywhere**: History badge, vehicle list, Talk answers, "what's my mileage?", conversion hint.
- [ ] Default-vehicle section (see §0).
- [ ] My places: add / edit (opens map picker) / delete.
- [ ] Reset driving profile (confirmation) — resets learned fields to `.new`.
- [ ] Clear trip history (confirmation).
- [ ] Disclaimer text present.

### 1.9 Map picker (only online-required feature)
- [ ] Settings → My places → Edit place opens `PlaceMapPicker` (center pin, search, use-my-location).
- [ ] Location permission prompt appears **only** when tapping the map button (When-In-Use).
- [ ] Dropping a pin + confirm saves precise lat/lon and a reverse-geocoded name.
- [ ] Using "Home"/"Office" in Calculate then uses those exact coordinates.
- [ ] With location **denied**, the flow degrades gracefully (search still works; the coordinate saves even if reverse-geocode fails, showing "lat, lon").
- [ ] Optional map picker in Calculate upgrades the estimate to precise `MKDirections` road distance when online; falls back to haversine×1.3 offline.

### 1.10 Talk to aigos
- [ ] Chat button in the Calculate header opens Talk.
- [ ] Badge reads **"On-device · works offline"** — **NO** "Apple Intelligence" / device-requirement wording anywhere (v1.0 provider-neutral decision). ⚠️ **This is the first Xcode-26 build where the `FoundationModels` seam compiles in — verify the badge/`AIGateView` copy did not change.**
- [ ] Trip query: "Manila to Batangas in my Vios" → estimate → "Open in Calculator" hands off correctly (saved + learning calc).
- [ ] Vehicle DB: "what's the km/L of a Vios?" → answer with **[Use this efficiency]** / **[Enter manually]** → prefilled `AddVehicleView`.
- [ ] Efficiency figures in answers follow the unit preference.
- [ ] EV query (e.g. a BYD/Tesla) → reports **km/kWh**, **no** "Use this efficiency" button (EV cost out of scope).
- [ ] Tagalog phrasings normalize ("Magkano ang gas papuntang…", "Gaano kalayo…").
- [ ] Small talk: greeting / thanks / goodbye / confusion + off-topic redirect.
- [ ] KnowledgeBase: fuel-economy tips, troubleshooting, PH car culture, typhoon advice, drive-vs-bus, CO₂, best-time-to-travel.
- [ ] **Toll** lookup ("toll to Baguio") → route toll + Class-1 note + "verify at expressway.ph".
- [ ] RFID load / which-RFID, MMDA number-coding, expressway emergency contacts answer offline.
- [ ] Follow-ups accumulate conditions ("same trip but it's EDSA on a Friday", "what about with cargo", "in my truck").

### 1.11 Self-learning profile
- [ ] After several trips, confidence advances (new 0–4 / building 5–14 / confident 15+).
- [ ] "Same as last time?" one-tap confirm remembers the last answers per vehicle.

---

## §2. Known potential bugs to watch for

These are the highest-risk areas given the codebase history and platform.

1. **Default-vehicle crash (build 60 P0 — FIXED build 61).** Re-verify §0 fully. Watch for any state where two vehicles show a checkmark, or a crash when the triggering view's `@Query` is momentarily stale. The fix fetches from the context, so a stale snapshot should no longer cause a double-default.
2. **Fuel-unit pill not toggling.** Historically the pills were `.onTapGesture` on `Text` (flaky hit area). Now real `Button`s — tap the pill directly (not the label edge) and confirm it switches. Can't be verified headlessly; **must** be a device tap.
3. **Talk badge regressing to Apple-Intelligence framing.** First build compiled with the iOS 26 SDK where `#if canImport(FoundationModels)` is now **active**. Confirm no "Apple Intelligence" / "requires a supported device" copy leaked into the Talk badge or `AIGateView`.
4. **Delete-default not promoting.** After deleting the default with other vehicles present, a new default must be auto-set. Verify exactly one remains and history is intact.
5. **Map picker permission / offline degradation.** Denying location must not crash; reverse-geocode failure must still save the coordinate.
6. **SwiftData `@Query` mutation during view update.** Setting default inside a `ForEach` Button — watch the console for "Modifying state during view update" / AttributeGraph cycles; watch for visual flicker.
7. **DrivingProfile has no inverse relationship** (one-way `.cascade` + manual `vehicleId`). Verify deleting a vehicle cascade-deletes its `DrivingProfile` and never orphans one (covered by tests, but confirm on-device that trip history survives).
8. **Distance estimate accuracy.** Offline is haversine×1.3 — sanity-check a couple of known routes look plausible (all distances must show the "≈" prefix).
9. **Count-up animation on cost.** Ensure the receipt counts 0→final smoothly and lands on the exact PHP value (no rounding drift between the count-up and the breakdown).
10. **Onboarding step-0 progress bar.** Must be hidden on the welcome hero, visible from step 1.

---

## §3. Edge cases to test

**Vehicles / default**
- [ ] Zero vehicles: Calculate is unusable gracefully; Settings hides the default section.
- [ ] Exactly one vehicle: it's always default; "Set as Default" hidden in its context menu.
- [ ] Many vehicles (8+): list scrolls; default logic still leaves exactly one.
- [ ] Two vehicles with identical names: still individually addressable (backed by `id`).
- [ ] Rapidly tapping "Set as Default" on the same row: idempotent, no double-default.

**Calculate**
- [ ] Same origin and destination (0 km): no crash; result is sensible/zero-ish.
- [ ] Very long route (e.g. Manila → Davao gazetteer pair): no overflow, PHP formats.
- [ ] Extreme driving factors stacked (city + standstill + full load + AC + old + overdue PMS): adjusted efficiency stays positive, litres finite, no divide-by-zero.
- [ ] Efficiency entered as a tiny value (e.g. 1 km/L): no infinity/NaN.
- [ ] Fuel level empty tank: low-fuel warning fires.
- [ ] Switching unit mid-flow: efficiency fields and results stay consistent.

**Places**
- [ ] Personal place with reverse-geocode failure offline: saves as "lat, lon".
- [ ] Alias collisions ("QC" vs a personal "QC"): personal place wins.
- [ ] Unicode / emoji in place or vehicle names: renders, persists, no layout break.

**Prices**
- [ ] Price set to 0: calculation yields PHP 0 without crashing.
- [ ] Price with many decimals: formats to a sane currency string.

**Persistence / lifecycle**
- [ ] Force-quit mid-calculation: relaunch is clean, no partial trip saved incorrectly.
- [ ] Background the app during the map picker, return: state intact.
- [ ] Change unit → force-quit → relaunch: unit preference persists.
- [ ] Airplane mode for the entire session: every core feature works; only the map picker degrades.

**Talk**
- [ ] Gibberish input: smart fallback, no crash.
- [ ] Very long message: handled.
- [ ] Query naming an unknown vehicle: graceful.

---

## §4. Device-specific checks

Test across a spread of sizes and OS versions.

| Device | OS | Why |
|--------|----|-----|
| iPhone SE (3rd gen) | 17.x | Smallest screen, oldest supported OS, Touch-ID-era layout, no Dynamic Island |
| iPhone 16 / 17 | 18.x & 26.x | Mainstream; verify both old and new SDK runtime behavior |
| iPhone 17 Pro Max / Air | 26.x | Largest screen, current SDK, ProMotion |

Checks per device:
- [ ] **Layout:** no clipped text, no horizontal scroll, tab bar not overlapping the home indicator; SE small-screen fits the `DrivingSheet` and result sheet.
- [ ] **Safe areas / notch / Dynamic Island:** headers and the floating tab bar clear all insets.
- [ ] **Dynamic Type:** bump to the largest accessibility text size — labels wrap, buttons stay tappable, currency stays on one line where it matters.
- [ ] **Dark / Light:** the app is dark-glass by design — confirm contrast and that system light mode doesn't wash out text.
- [ ] **Haptics:** light on Calculate start, medium on result reveal, success on save, selection on unit/default changes — felt on device only.
- [ ] **Custom tab bar taps:** every tab reachable by touch (the simulator can't tap it; QA must use a device).
- [ ] **ProMotion:** count-up and indicator animations are smooth at 120 Hz.
- [ ] **Location prompt:** appears only on the map button; "When In Use" string reads correctly.
- [ ] **Low Power Mode:** animations still complete; no stalls.
- [ ] **Rotation:** app is portrait-only — confirm it stays portrait.
- [ ] **iOS 26-specific:** confirm the Talk badge copy (FoundationModels seam now compiled in) and that nothing in the new SDK changed the glass styling.

---

## §5. Offline & privacy verification

- [ ] Enable Airplane Mode. Complete a full trip calculation, save it, view History, use Talk, edit prices — all succeed.
- [ ] Confirm **no** account/login prompt anywhere.
- [ ] Confirm **no** analytics/tracking prompt and **no** ATT prompt.
- [ ] Location is requested **only** at the map button, never at launch.
- [ ] Settings → Privacy → Location shows aigos as "While Using" only after the user opts in.

---

## §6. How to report each bug found

File one report per distinct issue. Use this template (copy into the tracker /
TestFlight feedback / a GitHub issue on `JimwellC/aigos`):

```
### [Pxx] Short title

**Severity:** P0 (crash / data loss / blocks submit) · P1 (broken feature) ·
              P2 (wrong behavior, workaround exists) · P3 (polish/cosmetic)
**Build:** 61 (6787352080)
**Device / OS:** e.g. iPhone SE (3rd gen) / iOS 17.5
**Feature area:** e.g. Vehicles → Set default   (map to §1.x above)
**Network state:** Airplane mode / Wi-Fi / Cellular

**Steps to reproduce (numbered, from a known start state):**
1. Fresh install (or -seedDemo) …
2. …
3. …

**Expected:**
**Actual:**

**Frequency:** always / intermittent (x of y tries)
**Regression?:** worked in build __ / new

**Evidence:**
- Screenshot or screen recording (required for UI bugs)
- Crash log: Settings → Privacy & Security → Analytics & Improvements →
  Analytics Data → find `aigos-*.ips`, or TestFlight's crash report, and attach the full symbolicated trace
- Console log excerpt if reproducible while attached to Xcode
```

**Severity guidance**
- **P0** — any crash, data loss, a state that blocks App Store submission, or a
  privacy violation (e.g. location requested at launch). File immediately; these
  block the release.
- **P1** — a core feature is broken or gives clearly wrong numbers with no
  workaround.
- **P2** — wrong or confusing behavior with a workaround; unit/label mismatches.
- **P3** — cosmetic, copy, spacing, animation polish.

**For crashes specifically:**
1. Reproduce with exact steps and note the **network state** and **device/OS**.
2. Capture the crash log (path above) and attach the **full** trace.
3. Note whether it reproduces on a second device.
4. If it's a default-vehicle crash, this is a **P0 regression of the build-61 fix** — flag it as such and include which §0 row triggered it.

---

## §7. Debug/QA launch args (developer, for reproducing states quickly)

These drive the app headlessly from `simctl` (the custom tab bar can't be tapped
from the simulator). See `Support/DebugSupport.swift`.

```bash
# Seed a 2-vehicle garage + trips + a saved route, open a tab:
xcrun simctl launch "iPhone 17" com.aigos.app -seedDemo -tab history
```

- `-seedDemo` — wipe + seed 2 vehicles / trips / a route, marks onboarded
- `-seedEmpty` — onboarded but empty (empty-state screens)
- `-tab calculate|history|saved|prices|settings`
- `-vehicles` — open the garage · `-autoCalc` · `-lowFuel`
- `-talk` / `-talkQuery "…"` / `-talkQuery2 "…"`
- `-onboarding` / `-onboardingStep N` (0 = welcome hero, 1 = vehicle, 2 = driving, 3 = prices)
- `-driving` · `-mapPicker` · `-routePreview` · `-editPrice` · `-editPlace`/`-placeMap` · `-searchDemo "…"`
- `-fuelUnit kmPerL|lPer100km` — force the unit (feeds `@AppStorage`) for screenshots

> After `-tab`, terminate + sleep ≥2.5s before relaunching. There is no
> `-hasOnboarded` arg.

---

*Sign-off requires: §0 clean on ≥2 devices, all §1 rows ✅ or triaged, no open
P0/P1, and the Talk badge confirmed provider-neutral on the iOS 26 SDK build.*
