# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Deploy Rules (permanent — never violate)

**DO NOT run `fastlane beta` or `fastlane release` unless the user explicitly asks for it** (e.g. "push to TestFlight", "run fastlane beta", or "run fastlane release"). Every TestFlight/App Store upload counts against Apple's **daily upload cap**; pushing too many builds in one day triggers error **90382 ("Upload limit reached — please wait 1 day")**. This happened repeatedly (builds 84→92 in a day) because builds were auto-pushed after every change. Each push must be an explicit, deliberate decision by the user.

**Default workflow for every change — local only, no uploads:**
1. Make the changes.
2. **Build locally** to verify it compiles — `xcodebuild -scheme aigos -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build`.
3. **Run the unit tests** and verify all pass — `xcodebuild -scheme aigos -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' test` (or `fastlane test` — it does NOT upload).
4. Optionally verify on the simulator (`xcrun simctl`) or hand off for the user's device QA.
5. **Only push to TestFlight/App Store when the user explicitly says so.**

**Never auto-push builds.** `xcodebuild`, `xcrun simctl`, and `fastlane test` are always fine (local, zero uploads). `fastlane beta` (TestFlight) and `fastlane release` (App Store) upload a binary and MUST wait for an explicit instruction **each time** — approval for one push never carries to the next.

## Project state

**Sprints 1–3 built.** The `aigos.xcodeproj` app exists and builds warning-clean (Swift 6, iOS 17+); `aigos_architecture.pdf` remains the source-of-truth spec. Real jeepney mascot art is in place — **two** mascots, both delivered as source PNGs with a transparency-checker baked in as opaque pixels (strip it to real alpha with a scratchpad PIL/AppKit pass, never ship the raw checker): (1) `mascot.png` → front-facing badge in `Mascot.imageset`, used via `MascotView(imageName:"Mascot")` for the splash (168), Calculate header (44), Talk avatar (44), onboarding chat bubble (40); (2) `mascot_wave.png` → a **waving** jeepney (checker stripped + cropped) in `MascotWave.imageset`, used for the onboarding welcome hero and the subtle per-tab background watermark. `MascotView` takes `imageName` (default `"Mascot"`), plus `floatDistance`/`floatDuration` for the bob. The **app icon** is regenerated (scratchpad PIL) from `mascot_wave.png` — 85% scale, bled off the bottom-right, over a diagonal `#F5C97A→#C4793A` amber gradient, opaque 1024² no-alpha. The **wave background watermark** rides in `AigosBackground`'s opt-in `mascotPeek: CGSize?` param (rendered inside the orb `.overlay` so it can't inflate layout — same rule as the bokeh orbs), 300pt @ opacity 0.20, `.bottomTrailing`, on all 5 tab roots only (Calc 60/-70, History 65/-80, Saved 55/-75, Prices 60/-70, Settings 60/-80). `MascotEmptyState` is **text-only** (the tab watermark supplies its mascot — don't re-add a peek there or it doubles). Onboarding is now 4 steps: **0 = welcome hero** (large centered `Mascot`, 220pt, ±8pt/2.5s float), 1 = add vehicle, 2 = driving, 3 = prices; the progress bar is hidden on step 0. Don't reintroduce the `bus.fill` placeholder. Done: 5-tab shell with a custom **floating pill** tab bar (`AigosTabBar` — icon-only, amber `matchedGeometryEffect` indicator), SwiftData models, physics `CalculationEngine`, editable prices (tap-to-edit inline rows), trip history with month-over-month comparison + stats, saved routes with one-tap recalc, the self-learning `ProfileLearningEngine`, first-launch onboarding, animated splash + static launch screen, and "Talk to aigos" natural-language trip queries with an offline **vehicle knowledge base** (`TalkToAigosView` + `VehicleDatabaseService`). The whole UI follows the glassmorphism design system (see `UI_GUIDELINES.md` / `skills/swiftui-design.md`) built in `Support/DesignSystem.swift`. Reusable **native** animation primitives live in `Support/Animations.swift` (`staggeredAppear(index:)`, `PressableStyle`, `Shake`); count-ups use `contentTransition(.numericText)` driven by a spring. No third-party animation libraries — and note `Animatable.animatableData` can't be a stored property on a `@MainActor` `View` under Swift 6, so use `contentTransition`/`GeometryEffect` instead. An `aigosTests` unit-test target covers the pure logic (**248 cases**, all passing). Real app-icon + mascot art are done. Distances are gazetteer haversine×1.3 estimates offline, upgraded to precise `MKDirections` road distance when the optional map picker is used online (see the map/privacy notes below).

**Talk to aigos (v1.0 = offline parser only):** NL understanding runs through `TripQueryParser`, a deterministic offline parser that works on every device. Per the v1.0 product decision, the UI is **provider-neutral** — no "Apple Intelligence" or device-requirement wording anywhere (badge reads "On-device · works offline"). A seam for a real on-device system model is kept behind `#if canImport(FoundationModels)` in `AIAvailability` for v1.1 (this Xcode 16.4 / iOS 18.5 SDK doesn't ship the framework, so it's excluded now). Don't reintroduce Apple Intelligence framing in the UI or add `import FoundationModels` outside that guard.

**Routing (v1.0 = autocomplete-validated places → estimated distance):** places come from `GazetteerData.entries` (rich `GazetteerEntry`: title, province subtitle, coordinate, aliases like "BGC"/"EDSA"/"QC"). `GazetteerRouteResolver` derives an `index` (key + every alias → entry) and resolves via `lookup`/`entry(for:)`. `PlaceSearch.suggestions(...)` powers the `PlaceField` autocomplete (personal places first, then gazetteer, max 5); `PlaceSearch.exactKey(...)` is the validation gate (random text like "J" → nil). **`CalculateView` requires both origin AND destination selected from the dropdown** (`originKey`/`destinationKey` non-nil) before Calculate enables; distance is derived from the two picked places (haversine×1.3), OR the precise `MKDirections` road distance when a place is set via the map picker while online. `PlaceResolver` still resolves personal aliases before the gazetteer for `TripQueryParser`/Talk, and now also decodes map-picked `@pin:lat,lon` selection keys. **Personal places are now map-pinned:** `PersonalPlace` stores a precise `latitude`/`longitude` + reverse-geocoded `displayName` (legacy `gazetteerKey` still honored as a fallback), set via the center-pin `PlaceMapPicker` (Settings → Edit Place — the old city list is gone). `PlaceResolver.point` returns a personal place's exact `geoPoint` first, so using "Home"/"Office" in the calculator uses precise coordinates. Offline-safe: if reverse geocode fails the coordinate still saves and `mappedLabel` shows `lat, lon`. Manual free-text distance entry was removed in favour of validated place selection. The optional `LocationPickerView` (MapKit) lets users search/drop a pin; it's additive — the gazetteer estimate is the offline fallback. The gazetteer is built with `Dictionary(uniquingKeysWith:)` so a duplicate key can't crash launch; `lookup` is deterministic (longest contained key). The gazetteer now also carries **high-value specific places** (top Metro Manila malls, landmarks, universities, hospitals, plus all major **airports & seaports** with correct province subtitles) — ~253 entries; expand it incrementally, guided by `UnlistedSearchLog`.

**Multi-modal / cross-island trips (fixes the "Angeles → Davao impossible land distance" bug):** `IslandResolver` maps a place to its drivable **landmass** via `Resources/IslandDatabase.json` (province → island, plus city overrides for separate islands inside a mainland province — Boracay/Siargao/Samal; bridged islands like Leyte↔Samar and Mactan↔Cebu count as one). `IslandResolver.isCrossIsland(a,b)` is true only when both resolve to *different* landmasses (unknown places never block). `TravelRoutes` loads `Resources/FerryDatabase.json` + `FlightDatabase.json` (typical domestic routes/fares as **reference estimates** — 2GO/OceanJet/FastCat ferries, PAL/Cebu Pacific/AirAsia flights) with a bundled `disclaimer`. **`CalculateView`** blocks Calculate when the two picked places are cross-island (`crossIsland`) and shows a "Sea or air travel required" banner → **`TalkToAigosView`**. Talk's `crossIslandReply`/`interIslandMessage` (checked before the land intents) returns the full breakdown: land portion to the departure hub (real fuel in the user's vehicle) + typical flight & ferry estimates between hubs + destination land note + disclaimer. Never quote a continuous land distance for a sea/air trip.

## Where we left off (session end · 2026-07-05, session 5 — v1.0 FROZEN, awaiting submission)

**🏁 v1.0 is feature-complete and FROZEN. `main` is tagged `v1.0` at commit `9a6085b` (build 92).** No more features, no more fixes — the only remaining work is the App Store submission mechanics (blocked ~24h on Apple's upload cap; see the task list below).

**State:** builds warning-clean (Swift 6, iOS 17+), **248 tests passing**, everything committed + pushed to `github.com/JimwellC/aigos` (private, `main`, tag `v1.0`). Build number = git commit count. **Latest on TestFlight: build 84** — builds **90/91/92 did NOT upload** (Apple daily upload-limit 90382; see below). So TestFlight is missing the calm-animations pass (90), the onboarding feature screen (91), and the final metadata build (92).

**v1.0 submission status (as of session 5 end):**
- **Code frozen** at build 92 = tag `v1.0`. Do NOT commit app changes before the first successful upload, or the build number drifts from the tag (a metadata-only fix would need a re-tag).
- **Metadata finalized** in `fastlane/metadata/`: **privacy_url** = `https://ritzy-nebula-f7d.notion.site/aigos-Privacy-Policy-2d41569dab8180cc9cd6eef55d2c331d` (verified public — `notion.site`, no login gate; the old `app.notion.com` link was a login wall → would've been rejected); **support_url** = `https://www.facebook.com/jimwell.calma.2024/`; review **phone** = `+63 928 960 6868`.
- **BLOCKER: Apple daily upload limit (error 90382).** Three upload attempts on 2026-07-05 all failed (build 91 beta, build 92 release, build 92 beta) — we shipped too many builds in one day (84→92). Resets in ~24h. `fastlane release`/`beta` archive + sign fine; only Apple's server rejects the binary upload. **Per the new Build & Deploy Rules, only push when the user explicitly asks.**

**▶ NEXT-SESSION TASK LIST (v1.0 submission — do these when the user asks, after the ~24h upload-limit reset):**
1. **`cd ~/Documents/Aigos && fastlane release`** — uploads build 92's binary + metadata to App Store Connect (no auto-submit; `submit_for_review: false`). Metadata upload is idempotent. (Only on explicit user request.)
2. **Upload screenshots** to App Store Connect (6.7"; the `fastlane screenshots` lane isn't wired — `skip_screenshots(true)` — so do it in the ASC web UI, or drop PNGs in `fastlane/screenshots/en-US/` first).
3. **Verify metadata** in ASC (name/subtitle/description/keywords/promo/release notes/support & privacy URLs/review phone).
4. **Set in the ASC web UI (deliver can't do these):** **Category = Navigation**, **Age rating = 4+**, **Price/Availability**, and **App Privacy nutrition labels** — mirror `PrivacyInfo.xcprivacy`: **Location → Precise Location**, purpose **App Functionality**, **Not Linked**, **Not used for Tracking**; everything else Not Collected. (Full label + Notion-policy drafts are in this session's chat.)
5. **Click Submit for Review** (manual — nothing auto-submits).

**Earlier session-5 work (all committed):** builds 74–84 (three v1.1 features + foreground-only tracking crash fix + Feature 4 Smart Driving Insights + haptics pass + bug sweep), then: **minimal-haptics** rule (only 6 completion/confirmation haptics), the **FoodPanda/Grab tracking bar redesign** (minimized bar default + tap-to-expand bottom sheet, global in `ContentView`), the **first-End black-screen fix** (`.sheet(item:)` so the comparison data is never nil at present time + a too-short guard), the **calm-animation pass** (springs → easeOut, no matchedGeometry/bounce, `.opacity` transitions — kept only the result cost count-up spring), the **Talk auto-scroll fix**, and the **onboarding feature-highlights screen** (new 5-screen flow: Welcome → Feature highlights → Add vehicle → Driving → Prices; progress bar denominator 3→4). See the per-topic blocks below for detail.

**Toolchain gate RESOLVED.** The Mac is now on **Xcode 26.6 / iOS 26.5 SDK**; `sudo xcode-select` points at `/Applications/Xcode.app`. The old iOS-26-SDK 409 rejection is gone — `fastlane beta` archives, signs, and uploads cleanly. Builds **60 → 73** have shipped to TestFlight. On the iOS 26 SDK the `#if canImport(FoundationModels)` seam in `AIAvailability` is *active* but harmless: `status`/`isAvailable` are **never called at runtime** (the Talk badge is static text), so the UI stays provider-neutral ("On-device · works offline"). Don't reintroduce Apple-Intelligence framing.

**Device-QA arc (iPhone 11 / iOS 26.5.2) — all fixes shipped:**
- **P0 SwiftData crash** on "set default" / "Calculate" was a `swift_dynamicCastFailure` from a **no-inverse** `VehicleProfile→DrivingProfile` relationship (found via build-60/63 `.ips` crash logs — symbolicated with the archive dSYM). Fixed by making the relationship **bidirectional** (`@Relationship(inverse:)` + `DrivingProfile.vehicle`), plus a **store-open recovery** in `aigosApp` that deletes an unopenable store and resets `hasOnboarded` instead of looping in a volatile in-memory store (builds 63/64).
- **Tank sizes:** per-vehicle `VehicleProfile.tankCapacityL` + real values in `VehicleDatabase.json`; fuel-gauge remaining-range + long-trip/refuel warnings; per-type fallback (**car 45 / motorcycle 5 / truck 75 / van 65** = `VehicleType.typicalTankLiters`); `AppSeeder.normalizeTankCapacitiesIfNeeded` one-time fix for legacy motorcycles stuck at the flat 45 L (builds 65/71).
- **Database-first vehicle add** (`VehicleSearchStep`: search + autocomplete + fuzzy/nicknames/category + "not listed" manual fallback), auto-fill, `UnlistedSearchLog` (private, local-only) (build 66).
- **Hybrid online/offline place search:** `PlaceField` autocomplete now also queries **Apple Maps (MKLocalSearch)** when online (debounced), with a 🌐/📵 `NetworkMonitor` indicator + an offline "not found" message; offline stays gazetteer-only (build 70).
- **Map-picker fixes:** `LocationHelper` rewrite — permission-first, `kCLLocationAccuracyHundredMeters`, cached fix, spinner, 5 s timeout; `LocationPickerView` remembers the last confirmed pin via `initialCoordinate` (build 72).

**Local offline coverage (build 73):** the offline gazetteer now covers the developer's home region — **Central/Northern Luzon: Pampanga, Bulacan, Tarlac, Nueva Ecija, Zambales, Bataan, Pangasinan, La Union, Baguio (Benguet)** — with ~81 places whose coordinates were **verified via MKLocalSearch** (malls, bus terminals, universities, hospitals, landmarks) plus local aliases ("dau", "clark", "marquee", "nepo", "fields", "hau", "auf", "sbma", "burnham"). Everywhere else, online Apple Maps search fills the gaps. Expand further based on `UnlistedSearchLog` demand.

**Three "v1.1" features PULLED INTO v1.0 and SHIPPED (builds 74–78):**
- **GPS Trip Tracking** — `TripTracker` (shared, `@Observable`) drives a battery-tuned `CLLocationManager` (`kCLLocationAccuracyHundredMeters`, 50 m distance filter, `.automotiveNavigation`, `pausesLocationUpdatesAutomatically`, background updates + blue indicator, requests **Always only on "Track This Trip"**, auto-detects arrival ≤500 m/2 min). Flow: result sheet **"Track This Trip"** → live `TripTrackingBanner` (distance/fuel/cost/speed/elapsed) on Calculate → **End Trip** → `TripComparisonView` (estimate vs actual + accuracy % + "Update my profile"). Saved as `TrackedTrip` (+ `TripRecord.isTracked`). **No fuel sensor** → "actual" fuel/cost are DERIVED from GPS distance; the self-correction folds the distance-estimate error into an effective km/L (`rated × est/actual`, clamped).
- **Fuel Purchase Logging** — `FuelLog` @Model + `FuelLogFormView`; `FuelReport.trueEfficiency` computes real fill-to-fill km/L from the two most recent full-tank logs with odometers → History "REAL EFFICIENCY DETECTED" insight.
- **Monthly Fuel Report** — `FuelReport.monthly` aggregates `TripRecord`s (+`FuelLog`s) → `MonthlyReportView`, rendered to a 1080×1920 share card via `ImageRenderer` → `UIActivityViewController`.
- Supporting: **History redesigned** with a segmented control **Trips / Fuel Log / Report**; **Talk** gained `fuelLogReply` (parses "I just filled up 35 L at Shell for 2,520" via `FuelLogParser` and saves), `reportReply`, `accuracyReply` + new chips. Pure logic in `TripMetrics`/`FuelReport`/`FuelLogParser` is unit-tested. The remaining v1.1 roadmap items (remote prices, station finder, widgets, watch) are still planned.

**GPS tracking is now FOREGROUND-ONLY (crash fix, build 80).** Build 78's tracker set `allowsBackgroundLocationUpdates = true`, but the built `Info.plist` was **missing `UIBackgroundModes = [location]`** (the `INFOPLIST_KEY_UIBackgroundModes = location` build setting silently emitted nothing — verified via `plutil`). iOS throws `NSInvalidArgumentException` → SIGABRT whenever tracking began with **"Always"** authorization. That's the "worked once (While-Using), then crashed every time (iOS escalated to Always)" bug — not network-related. Fix: `TripTracker` no longer touches `allowsBackgroundLocationUpdates`/`showsBackgroundLocationIndicator`, requests **`requestWhenInUseAuthorization`** (not Always), and pauses on background (`UIApplication.didEnterBackgroundNotification` → stop updates, `status = .paused`, quiet provisional local notification) + auto-resumes on foreground. `Info.plist` now carries **only** `NSLocationWhenInUseUsageDescription` — no Always key, no background mode (confirm with `plutil`). Never re-enable background location without a real `UIBackgroundModes` Info.plist entry, verified in the built app. UI: "Keep aigos open while driving to track your trip" note on the result sheet + banner.

**Feature 4 — Smart Driving Insights SHIPPED (build 82).** Makes the self-learning `DrivingProfile` visible.
- **`DrivingScorer`** (pure) → a 0–100 fuel-efficiency `DrivingScore`: Speed vs optimal 30 · AC efficiency 15 · Smooth-driving (GPS accuracy proxy — no accelerometer) 15 · Rush-hour avoidance 20 · Maintenance 20. Labels: 🏆 Fuel Master (90+) / ⭐ Smart Driver (75+) / 👍 Getting There (60+) / 📈 Room to Improve. `score(for:trips:trackedTrips:)` pulls inputs from the models (trips keyed by `vehicleName`).
- **`SuggestionEngine`** (pure): personalized tips from the last 30 days — `speed`/`ac`/`timing`/`maintenance`/`fuelType`, each with an estimated PHP saving. `pick()` returns ≤3, prefers tips not shown in 7 days, rotates by day; `SuggestionLog` persists shown-dates in local UserDefaults.
- **`DrivingDashboardView`** (Settings → **Driving Insights**): score ring + component breakdown, "how you drive" stats, personalized tips, a garage comparison (2+ vehicles), and a shareable **1080×1920 `ScoreShareCard`**. **`SuggestionCard`** (reusable, dismissable) also shows on Calculate below the vehicle card (max 1). **Talk** gained `drivingReply` ("How's my driving?"), `saveTipsReply` ("How can I save fuel?"), `costTrendReply` ("Why is my fuel cost increasing?") + chips. Covered by `DrivingInsightsTests`.

**Haptics are MINIMAL — completions/confirmations only (build 84).** The rule: haptics mark COMPLETIONS and CONFIRMATIONS, **never navigation or selection**. ~38 call sites were removed (tab switch, pill/fuel-type selection, input taps, sheet open/close, autocomplete, map-pin drop, accordion, saved-route recalc, onboarding/splash, Talk send, vehicle delete/edit, suggestion dismiss, "update profile", etc.). The `Haptics` enum (`tap`/`success`/`selection` in `DesignSystem.swift`) is unchanged — only call sites were pruned. **Exactly 6 haptics remain — do not add more without matching this list:** Calculate button press (`tap(.medium)`) · result sheet appearing (`success()`) · "Track This Trip" start (`tap(.medium)`) · "End Trip" confirmation (`success()`) · vehicle set as default (`tap(.light)`, both garage + Settings entry points) · fuel log saved (`tap(.light)`).

**Pre-submission bug sweep (build 84).** A 4-agent parallel audit (divide-by-zero, SwiftData threading, empty-state/nil-vehicle, tracker/memory/fuel-log) across 18 areas. The app was already solid — **no** divide-by-zero (efficiency clamped to 0.1; every average gated on non-empty), **no** off-main `ModelContext` access (`TripTracker` holds only value copies — no `ModelContext`, so deleting a vehicle mid-track is safe), **no** retain cycles, all empty-state/nil-vehicle paths guarded. Fixed the real gaps: `CalculationEngine.estimate` now sanitizes a non-finite/negative distance or price to 0 (would otherwise persist NaN/Inf into `TripRecord` and trap in `Int()`/gauge rendering; +regression test); `FuelLogFormView` enforces upper bounds (litres ≤ 1000, cost ≤ 1,000,000) + warns on an odometer lower than the vehicle's last logged reading; `startTracking` guards against a double-start. Known non-crash edge (not fixed): GPS/location services fully off leaves `TripTracker.status == .requesting` (silent no-op, banner never appears) — device-QA item.

**Fastlane — COMPLETE & WORKING** (uploads cleanly on Xcode 26; run `fastlane beta` to push a build). Installed via Homebrew (vendors its own Ruby; system Ruby 2.6 is too old). `fastlane/` has `Appfile` (bundle `com.aigos.app`, team `MWJJ994KSX`), `Fastfile` lanes — `test` / `build` / `beta` (TestFlight) / `release` (App Store, no auto-submit) / `metadata` / `verify` (read-only ASC auth check) — authed by an **App Store Connect API key configured in `fastlane/.env`** (gitignored; template in `.env.template`). Build number = git commit count injected at build time (`CURRENT_PROJECT_VERSION` via xcargs). `deliver` metadata is wired from `docs/app-store/` into `fastlane/metadata/`. `fastlane/SETUP.md` is the human guide; `fastlane/README.md` is auto-generated. Analytics opted out.

**App Store Connect:** the app record for **`com.aigos.app` exists (App ID `6787352080`)**; `fastlane metadata` has pushed the full listing (name/subtitle/description/keywords/promo/release notes/review notes). **Three temporary placeholders still live in the listing** and must be replaced before submit: `support_url` = a Facebook page, `privacy_url` = an `app.notion.com` link (**verify it opens without login — Apple rejects gated privacy URLs; publish as `notion.site`**), review `phone_number` = a real number is set. `.gitignore` hardened for secrets (`.env`, `**/*.p8`, `fastlane/keys/`); no secret has ever been committed. `aigos_architecture.pdf` is untracked (on disk, gitignored).

**Shipped this session (session 3) — Talk/knowledge, physics modifiers, garage, units, polish:**
- **Talk to aigos accuracy pass** — `Services/TalkResponder.swift`: `TalkNormalizer` (Tagalog → English trip phrasings), `TalkSmallTalk` (greetings / thanks / goodbye / confusion + off-topic redirect). `VehicleDatabase` gained "[model] is a SUV" category clarification and "what SUVs are fuel-efficient?" top-3 rankings.
- **KnowledgeBase** (`Services/KnowledgeBase.swift`, offline) — fuel-economy tips (personalised savings), troubleshooting, PH car culture (jeepney/tricycle/family car), typhoon advice, drive-vs-bus cost, CO₂, best-time-to-travel, route facts, and a **toll database**. Data files: `Resources/RealWorldEfficiencyDatabase.json`, `RouteConditionsDatabase.json`, **`TollDatabase.json`** (TRB-approved 2026 Class-1 rates via expressway.ph — toll lookups carry the Class-1 note + "verify at expressway.ph"; plus RFID load/which-RFID, MMDA number-coding, and expressway emergency-contact responses).
- **Vehicle DB → 235 entries** incl. **13 EVs** (`fuel:"electric"`, `VehicleEntry.isElectric`; answers report **km/kWh** and skip the litre-based calc — EV cost model is out of scope). Efficiency figures in Talk follow the user's unit preference.
- **Efficiency modifiers wired into `CalculationEngine`** — `adjustedEfficiency = base / consumptionMult × efficiencyMult`. New *efficiency* factors (multiply, never add): **age** (`VehicleProfile.manufacturingYear` → `CalculationEngine.ageFactor` band), **maintenance** (`MaintenanceStatus`), **weather** (`WeatherCondition`, per-trip in `DrivingSheet`), **road surface** (`RoadSurface`, per-trip). `ResultCard` groups "Driving factors" vs "Vehicle factors" (green gain / amber loss) + an "Adjusted efficiency" row. Year is an optional field in `AddVehicleView`/onboarding; maintenance is a selector in `AddVehicleView`.
- **Map-based personal-place picker** — `Views/Settings/PlaceMapPicker.swift` (center-pin map, search, use-my-location) replaces the old city list; `PersonalPlace` stores precise `latitude`/`longitude` + reverse-geocoded `displayName`, and `PlaceResolver` returns those exact coords.
- **Vehicle garage edit / delete / set-default** — `VehiclePicker` is now a `List` with left-swipe (Edit + Delete) + long-press menu; `AddVehicleView` takes an optional `editing:` vehicle ("Edit Vehicle" / "Save changes" + default toggle). Delete confirms, **preserves TripRecord history**, and promotes a new default. `Haptics.success()` / `Haptics.selection()` added.
- **Calculate button** redesigned — deep brown pill (`#8A4E24→#6B3A1A`) with amber glow (was amber-on-amber, invisible); idle glow pulse, 56pt full pill, disabled 0.45.
- **Fuel-unit toggle** fully audited + fixed — km/L ↔ L/100km now flows **everywhere** (History badge, `VehicleDatabase.answer(unit:)`, Talk + "what's my mileage?", Settings conversion hint). The Settings unit pills are now real `Button`s (were `.onTapGesture` on a `Text` → flaky hit area, the reported "doesn't switch" bug).
- **App icon** redesigned from the waving mascot (oversized 85% scale, bled off bottom-right, opaque no-alpha).

**Submission P0 (code side) — DONE:** `PrivacyInfo.xcprivacy` (no data collected; Precise Location = App Functionality, not linked, not tracking; UserDefaults `CA92.1`), `ITSAppUsesNonExemptEncryption = NO`, `NSLocationWhenInUseUsageDescription`, AC "Sometimes" real 1.06 factor, "≈" prefix on all distances, `DEVELOPMENT_TEAM = MWJJ994KSX` (automatic signing).

**Remaining before App Store submission:**
1. **Update to macOS 26 + Xcode 26 (REQUIRED — the only upload blocker)**, `xcode-select` it, then re-run `fastlane beta`. Confirm the FoundationModels seam keeps the Talk UI provider-neutral.
2. **Replace the 3 temporary listing placeholders** (support URL, login-free privacy URL, phone) → re-run `fastlane metadata`. Host `docs/app-store/privacy-policy.md` publicly first.
3. **App Store Connect (web UI):** set category (**Navigation**), age rating **4+**, price tier, and App Privacy nutrition labels — must MIRROR `PrivacyInfo.xcprivacy`.
4. **Physical-iPhone QA:** the fuel-unit pill tap-to-switch (can't be verified headlessly), Vehicles swipe/long-press actions, `PlaceMapPicker` confirm round-trip, Talk → "Use this efficiency" handoff, keyboard toolbars, haptics.
5. **Marketing screenshots** (6.7") — the screenshots lane isn't wired yet (`skip_screenshots(true)`); drop PNGs in `fastlane/screenshots/en-US/`. Copy/captions/privacy/review-notes live in **`docs/app-store/`**.
6. **`fastlane beta`** (TestFlight) → device test → **`fastlane release`** (pushes binary + metadata; does NOT auto-submit).

**Known caveats / v1.1 backlog:** EV trip-cost model (PHP/kWh) not built — EV answers are informational km/kWh only; toll fees are informational, not folded into the calculated trip total; Talk age/maintenance questions are per-message (no model memory); the on-device fuel-unit pill tap needs one manual confirm; map picker + swipe actions want on-device tap verification; `FoundationModels` seam compiled out until Xcode 26; optional remote price fetch not built.
- **Real gas-station suggestions for "one tank" / refuel answers.** v1.0 intentionally uses a **generic** "you'll need a refuel stop along the way" message — do NOT fabricate station names/locations. For v1.1, add real stations either from official operator locator data (Shell / Petron / Caltex / Seaoil APIs) OR via `MKLocalSearch` for online, along-the-route station finding (online-only, with the generic message as the offline fallback). Applies to `TalkToAigosView.oneTankReply` and could also enrich the `ResultCard` refuel warning.

**DEBUG launch args (headless screenshots/QA — see `DebugSupport`):** `-seedDemo` (wipe + seed a 2-vehicle garage/trips/route, marks onboarded), `-seedEmpty` (onboarded but no data — empty-state screens), `-tab <calculate|history|saved|prices|settings>`, `-autoCalc`, `-lowFuel`, `-talk` / `-talkQuery "…"` / `-talkQuery2 "…"`, `-onboarding` (skips splash → onboarding; only when NOT onboarded), `-onboardingStep N` (**0 = welcome hero, 1 = add vehicle, 2 = driving, 3 = prices**), `-driving`, `-mapPicker`, `-routePreview`, `-editPrice`, `-editPlace` / `-placeMap`, `-vehicles` (open the garage), `-searchDemo "…"`. **`-fuelUnit <kmPerL|lPer100km>`** works via the NSArgumentDomain (feeds `@AppStorage`) to force the unit for screenshots. There is **no** `-hasOnboarded` arg. The custom tab bar can't be tapped headlessly, so `-tab` drives navigation; after `-tab`, terminate + sleep ≥2.5s before relaunch.

Extract the PDF text if you need to re-read the spec:

```bash
pip3 install --break-system-packages pypdf
python3 -c "from pypdf import PdfReader; print('\n'.join((p.extract_text() or '') for p in PdfReader('aigos_architecture.pdf').pages))"
```

## What aigos is

An offline, privacy-first iOS fuel-trip cost calculator for Filipino roads. Native SwiftUI (Swift 6, iOS 17+), one-time paid App Store app, zero backend, built solo. It follows the "Tarsi" playbook: ship in days, no login, no cloud, no ongoing cost, solve a Filipino-specific problem.

## Non-negotiable constraints (locked by the spec — do not re-litigate)

- **Offline-first, zero backend.** Every *core* feature must work with no internet. No cloud, no servers, no iCloud sync, no analytics/tracking SDKs. Two network exceptions are now allowed: (1) an optional v1.1 remote-JSON fuel-price fetch that falls back to cached values; (2) the **optional MapKit location picker** (`LocationPickerView`) — `MKLocalSearch`, `MKDirections` road distance, tiles, reverse geocoding, and one-shot `CLLocation`. This is an *enhancement*: the app still fully works offline via the gazetteer autocomplete + haversine estimate. When adding features, keep the offline path intact and gate anything networked behind graceful fallback. Note this deviates from the original "only fuel-price" rule — it was an explicit product decision.

- **Privacy (locked declaration).** `NSPrivacyTracking = false`. The app collects **no** data on its own servers (there are none). Location is used only **while the app is in use** (`WhenInUse`), in on-device-only, opt-in ways: (1) the map picker (tap the map button); (2) GPS **trip tracking** — **FOREGROUND-ONLY** in v1.0 — records the route on-device only while the user has aigos open, to compare estimate vs actual; (3) "use my location". **No "Always"/background location** and **no `UIBackgroundModes`** — trip tracking pauses when the app backgrounds and resumes on return (this was a deliberate v1.0 choice after a background-mode crash; see the notes below). Location is never stored on a server, transmitted, or linked to identity — tracked routes live in local SwiftData (`TrackedTrip`) and the user can delete them. `Info.plist` carries **only** `NSLocationWhenInUseUsageDescription` (no Always key, no background mode). `PrivacyInfo.xcprivacy` declares **Precise Location** as `AppFunctionality`, **not linked, not tracking**, plus the required-reason `UserDefaults` (`CA92.1`). Do not add data collection, tracking SDKs, an ATT prompt, or re-enable background location without the `location` `UIBackgroundMode` (a real Info.plist file, verified via `plutil`) — setting `allowsBackgroundLocationUpdates = true` without it **crashes**.

  **App Store Connect nutrition labels (mirror the manifest — set before submission):** under **Data Not Linked to You**, declare **Precise Location**, purpose **App Functionality**, **"Used for Tracking" = No**. Update the external **Notion privacy policy** with a GPS-tracking paragraph: *"Location is recorded only during active, opt-in trip tracking while the app is open; the route stays on your iPhone, is never shared, and you can delete any tracked trip."*
- **iOS only.** SwiftUI + Swift 6, minimum iOS 17. No React Native, no cross-platform, no Android. (The developer knows React Native but is new to SwiftUI — write complete, copy-pasteable SwiftUI, not snippets or pseudocode.)
- **SwiftData for all persistence.** No CoreData. No `UserDefaults` for complex objects. Use the default `ModelContainer`.
- **The spec is final.** Every decision in `aigos_architecture.pdf` (Section 6 decision log) is locked. Don't re-ask answered questions or propose alternatives unless the developer explicitly reopens a decision.
- **Currency renders as `PHP` prefix** (e.g. `PHP 261.43`), never the ₱ glyph — it renders inconsistently across devices.
- **App name is `aigos`** — always lowercase, never capitalized.
- **Primary accent color** is amber `#E9A84C`.

## Architecture

Launch flow: the static `LaunchScreen.storyboard` (a composed `LaunchImage` — gradient + mascot + wordmark) shows instantly, then `RootView` (in `aigosApp.swift`) shows the animated `SplashView` and fades into `ContentView`. Splash auto-advances (~1.8s) for returning users; first-launch shows a "Get Started" CTA → onboarding (whose own welcome screen was removed to avoid duplication).

Flat `TabView` with 5 tabs (no deep `NavigationStack` hierarchies — every feature is one tap from anywhere): **Calculate** (`car.fill`, default) · **History** (`clock.fill`) · **Saved** (`star.fill`) · **Prices** (`fuelpump.fill`) · **Settings** (`gearshape.fill`).

Planned structure (Section 17 of the spec): `App/` (`aigosApp.swift` @main + ModelContainer, `ContentView.swift` TabView), `Models/` (SwiftData @Model entities + `Enums.swift`), `Views/` (one folder per tab, plus `TalkToAigos/` and `Onboarding/`), `Services/` (`CalculationEngine`, `OSRMService`, `PriceService`), `Resources/` (`FuelPrices.json`, bundled PH OSRM road data), `Assets.xcassets`.

### SwiftData models (Section 9)

`VehicleProfile` (has a `@Relationship` to a per-vehicle `DrivingProfile`), `TripRecord` (auto-saved on every calculation as a full breakdown snapshot), `DrivingProfile` (per-vehicle, self-learning), `SavedRoute`, `FuelPriceCache` (one row per fuel type), `PersonalPlace` (named shortcut `name`→`gazetteerKey`, e.g. "Home"→"makati"). Enums: `VehicleType`, `FuelType {unleaded91, premium95, premium97, diesel, premiumDiesel, eGasoline}` (PH pump names — raw values are the `FuelPrices.json` keys; `FuelType.detect(in:)` maps old RON + new names for Talk), `RoadType {highway, city, mountain, mixed}`, `TrafficCondition`, `VehicleLoad`, `FuelLevel`, `ACUsage {always, sometimes, off}` (UI-only 3-state AC; `.isOn` drives the binary estimate), `ProfileConfidence {new, building, confident}`. Seed `FuelPriceCache` (from `FuelPrices.json`) and empty `PersonalPlace` shortcuts (Home/Office/School) on first launch via `AppSeeder`. **Any new @Model must be added to the schema in `aigosApp` AND every view's `#Preview` `.modelContainer(for:)` list.**

### Core calculation (Section 8 — implement exactly)

Physics-based, not simple multipliers. The result screen must show a full breakdown, not just a number — this transparency is a core product principle.

**Driving options:** the "How you'll drive" card is a tappable summary row (truncated one-liner like "Highway · 110 km/h · AC on · Heavy traffic") that opens `DrivingSheet` — a `.large` bottom sheet (drag indicator + X + Done, `presentationBackground { AigosBackground() }`) with amber-pill sections for Speed (Highway/City buckets), Air conditioning, Road type, Traffic (+ rush-hour toggle), Passengers & load, Fuel level. Bindings apply live, so the summary updates on dismiss. (The old inline expand — which had no way to collapse — is gone.)

**Result presentation:** the Calculate screen stays clean (vehicle · route · driving profile only). Tapping Calculate shows a loading state (`isCalculating` → spinner + "Calculating…" with an intensified amber glow, light haptic on start), computes immediately, then after a **minimum 1.2s** reveals the result as a bottom **`.sheet`** (`ResultSheet`, `.presentationDetents([.large])`, drag indicator, `.presentationBackground { AigosBackground() }`, medium haptic on reveal). `ResultSheet` = route header ("Origin → Destination" + vehicle name) → `ResultCard` receipt (owns its own 0→final count-up via `heroCost`) → "Save this route" (secondary) + "Done" (primary). Swipe-down dismisses back to the form to adjust. `startCalculate()` orchestrates loading+delay; `performCalculation()` computes/persists/learns. `ResultCard` is never rendered inline anymore.

```
adjustmentMultiplier  = speedFactor * acFactor * roadFactor * trafficFactor * loadFactor   // consumption ↑
efficiencyMultiplier  = ageFactor * maintenanceFactor * weatherFactor * roadSurfaceFactor   // efficiency ×
adjustedEfficiencyKmL = baseEfficiencyKmL / adjustmentMultiplier * efficiencyMultiplier
litresNeeded          = distanceKm / adjustedEfficiencyKmL
estimatedCost         = litresNeeded * fuelPricePerLitre
```

**Two factor families (kept separate for the breakdown).** The 5 *driving* factors above are **consumption** multipliers (≥1 divides efficiency). The 4 *vehicle/condition* factors are **efficiency** multipliers (<1 lowers economy) and MULTIPLY the efficiency — they compound, never add. `ResultCard` shows them under a "Vehicle factors" header (green badge for a gain, deep-amber for a loss). All default to no-effect so existing callers are unaffected.
- `ageFactor` (`CalculationEngine.ageFactor(forYears:)`, from `VehicleProfile.manufacturingYear`) — 0–2 yr `1.00`, 3–5 `0.92`, 6–10 `0.85`, 11–15 `0.75`, 16+ `0.65`.
- `maintenanceFactor` (`VehicleProfile.maintenanceStatus`, `MaintenanceStatus`) — well-maintained `1.05`, average `1.00`, overdue PMS `0.85`.
- `weatherFactor` (per-trip `WeatherCondition` in `DrivingSheet`) — clear `1.00`, light rain `0.97`, heavy rain `0.92`, extreme heat `0.90`.
- `roadSurfaceFactor` (per-trip `RoadSurface` in `DrivingSheet`) — smooth `1.00`, city `0.95`, rough `0.88`, unpaved `0.80`.
- Year is an optional field in `AddVehicleView` + onboarding; maintenance is a selector in `AddVehicleView`. Talk applies age (band-based) + maintenance from the vehicle; "My car needs PMS" → `KnowledgeBase` advice.

- `speedFactor` — lookup table (Section 14E): <60 km/h → 1.18, 60–80 → 1.08, 80–100 → 1.00 (optimal), 100–120 → 1.13, >120 → 1.22.
- `acFactor` — `1.12` when AC on, else `1.0`.
- `roadFactor` — highway `1.00`, city `1.20`, mountain `1.35`.
- `trafficFactor` (`TrafficCondition`) — light `1.00`, moderate `1.08`, heavy `1.25`, standstill `1.35`. Rush hour + city road auto-suggests heavy.
- `loadFactor` (`VehicleLoad`) — driver-only `1.00`, 3–4 pax `1.05`, full `1.10`, cargo `1.15`.
- `traffic`/`load` default to `.light` on `estimate(...)`, so any caller that omits them is unaffected. All factors are shown as separate rows in `ResultCard`.
- Low-fuel warning: pass `availableFuelLitres` (= `FuelLevel.fraction × VehicleType.typicalTankLiters`); `FuelEstimate.needsRefuel` is true when `adjustedLitres` exceeds it. Doesn't affect cost.
- Settings offers an L/100km toggle: convert `kmL = 100.0 / l100kmValue` before feeding the formula.

### Smart Driving Profile (Section 14 — the key differentiator)

Per-vehicle, set via the "Talk to aigos" hybrid interview (mascot chat bubble + tap-to-answer buttons, no keyboard) before each trip, and self-corrects from trip history. After each trip, `ProfileLearningEngine.updateProfile` updates a rolling average (recent 10 trips weighted most) and bumps `confidenceLevel` by trip count (0–4 new / 5–14 building / 15+ confident). Remember the last answers per vehicle and offer a one-tap "Same as last time?" confirm.

### Talk to aigos / Apple Intelligence gate (Section 13)

"Talk to aigos" (`Views/TalkToAigos/`) answers plain-English trip queries. Entry point is the chat button in `CalculateView`'s header. Pipeline: `TripQueryParser.parse` extracts origin/destination/vehicle (reusing the gazetteer via `GazetteerRouteResolver.lookup`/`isPlace`/`isPlaceKey`) → `CalculationEngine` estimates → the reply offers "Open in Calculator", which hands a `CalculatorDraft` to `CalculateView` for the real (saved + learning) calc. `AIAvailability` is the gate (`#if canImport(FoundationModels)` for the real system model, else offline parser) and drives the header badge + `AIGateView`. **The core app — and Talk to aigos — must work 100% without Apple Intelligence on any iOS 17+ device** (the parser is deterministic and offline); AI only enhances understanding when present.

**Vehicle knowledge base:** `VehicleDatabaseService` (loads bundled `Resources/VehicleDatabase.json` — 65 top PH cars + motorcycles with real-world km/L, fuel, type, category) answers "what's the km/L of a Vios?" style questions offline. `VehicleDatabase.answer(for:) -> VehicleAnswer?` classifies the message (Premium-95 advice, how-to-measure explainer, age/engine-wear ×0.85, fuel-type, exact/fuzzy model lookup with Levenshtein typo tolerance + variant disambiguation, or Tier-2 category range fallback) and returns nil when it isn't a vehicle question. Talk checks it **after** trip/follow-up parsing (so "Manila→Batangas in my Vios" stays a trip). A found model renders **[Use this efficiency]** / **[Enter manually]** buttons → `appState.addVehicle(VehicleDraft)` → `CalculateView` opens `AddVehicleView` prefilled (efficiency converted to the user's unit). The DB now has **235 vehicles** (incl. 13 EVs); `answer` also handles "[model] is a SUV" category-clarification, "what SUVs are fuel efficient?" top-3 rankings, EV km/kWh answers, and formats efficiency figures in the user's `FuelUnit`.

**Conversational + knowledge layers (offline):** `Services/TalkResponder.swift` — `TalkNormalizer` rewrites common Tagalog phrasings ("Magkano ang gas papuntang…", "Gaano kalayo…", "Anong gasolina para sa…") into English, and `TalkSmallTalk` handles greetings/thanks/goodbye/confusion + an off-topic redirect. `Services/KnowledgeBase.swift` answers fuel-economy education, troubleshooting, Filipino car culture (jeepney/tricycle/family car), seasonal advice, route facts, drive-vs-bus cost, CO2, and best-time-to-travel — backed by two bundled data files (`Resources/RealWorldEfficiencyDatabase.json` real-world km/L modifier factors: age/maintenance/tires/driving/cargo/time/weather/road/elevation; `Resources/RouteConditionsDatabase.json` major-route distance/toll/time/gas-stops). **Talk `reply()` order:** normalize → small talk → KnowledgeBase (before trip parse, since these often name a place) → trip → follow-up → `VehicleDatabase` → smart fallback.

**Toll + expressway knowledge:** `Resources/TollDatabase.json` (TRB-approved 2026 Class-1 rates via expressway.ph — 12 expressways with segments, 12 common full routes, RFID systems). `KnowledgeBase` answers toll lookups ("toll to Baguio" → route toll + the mandatory Class-1 note + "verify at expressway.ph" disclaimer), RFID load/which-RFID, MMDA number coding, and expressway emergency contacts — all checked **before** the route-facts/trip intents (toll shares the "toll" keyword). **Vehicle DB is now 235 entries** including **13 EVs** (`fuel:"electric"`, `VehicleEntry.isElectric`); EV answers report **km/kWh** and skip the litre-based "Use this efficiency" button (the trip calculator is petrol/diesel-priced — EV cost is out of scope). Note: the request's `RealWorldModifiers.json` duplicated the existing `RealWorldEfficiencyDatabase.json`, so that file was extended (clogged injectors, cruise control) rather than duplicated. Covered by `VehicleDatabaseTests`, `TalkResponderTests`, `KnowledgeBaseTests` (**248 tests total**).

**Conversational follow-ups:** the chat keeps `lastQuery`. A message with no route of its own but with condition hints / a follow-up phrase / a vehicle change (e.g. "same trip but it's EDSA on a Friday", "what about with cargo", "in my truck") is routed through `FollowUp.merge` (in `Services/FollowUp.swift`), which layers the new `TripHints` (from `TripQueryParser.hints(from:)`) onto the previous trip — unspecified fields keep their prior value, so conditions accumulate.

### Routing (highest technical risk — prototype first)

OSRM + a bundled Philippine OpenStreetMap dataset, fully offline, zero per-call cost. Target the compressed bundle under 100MB; if it exceeds the limit, fall back to manual distance entry (or App Store on-demand resources). Prototype and de-risk this before building anything else in Sprint 1.

## Build & run

Build/run via **Xcode 16+** (required for SwiftUI + Foundation Models), or headlessly:

```bash
xcodebuild -scheme aigos -destination 'platform=iOS Simulator,name=iPhone 16' build
xcrun simctl install "iPhone 16" \
  build/DerivedData/Build/Products/Debug-iphonesimulator/aigos.app
xcrun simctl launch "iPhone 16" com.aigos.app
```

Tests (**248 cases** covering the pure logic — `CalculationEngine` (incl. efficiency modifiers), `ProfileLearningEngine`, `TripQueryParser`, `GazetteerRouteResolver`, `FuelUnit`, `VehicleDatabase`, `KnowledgeBase`, `TalkResponder`, vehicle deletion, formatting, `MonthGroup`):

```bash
xcodebuild -scheme aigos -destination 'platform=iOS Simulator,name=iPhone 16' test
# single test:
xcodebuild -scheme aigos -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:aigosTests/CalculationEngineTests/testSpecWorkedExample
```

The project uses Xcode 16 **synchronized folder groups** (`PBXFileSystemSynchronizedRootGroup`) — new files under `aigos/` (app) and `aigosTests/` (tests) are picked up automatically; no need to edit `project.pbxproj` when adding sources. Tests use `@testable import aigos`, so app types can stay `internal`.

**DEBUG launch args** (see `Support/DebugSupport.swift`) drive the app headlessly for screenshots/QA — the custom tab bar can't be tapped from `simctl`:

```bash
# seed a demo garage + trips across two months + a saved route, open a given tab:
xcrun simctl launch "iPhone 16" com.aigos.app -seedDemo -tab history
#   -tab: calculate|history|saved|prices|settings   (calculate auto-runs a sample estimate)
```

The `aigosTests` target covers the pure logic (**248 cases**, all passing) — run it with the `test` command above or `fastlane test`.

## Roadmap (Section 20)

- **Sprint 1 (default start):** Xcode + SwiftData `ModelContainer` setup, TabView skeleton, the four SwiftData models, an **OSRM prototype** (do this first), `CalculateView` (origin/destination input, vehicle picker, result card), `CalculationEngine`, editable `PricesView`. *Done when:* a user can pick a vehicle, enter origin + destination, tap calculate, and see a PHP fuel cost.
- **Sprint 2:** auto-save trips → `HistoryView` with month-over-month comparison, `SavedRoutesView`, `SettingsView`, 3-screen onboarding, app icon + jeepney mascot assets.
- **Sprint 3:** Apple Intelligence / `TalkToAigosView`, `AIGateView`, App Store assets + submission.

When starting fresh, default to Sprint 1 unless told otherwise. Keep scope tight — feature creep is the named enemy; ship imperfect and iterate.

## v1.1 Roadmap (documentation only — do NOT build until v1.0 ships)

Full specs for the next development cycle. Keep the v1.0 constraints (offline-first, zero backend, privacy-locked, SwiftData, iOS-only) — every networked piece must degrade gracefully offline.

> **NOTE:** the first three features below — **GPS Trip Tracking, Fuel Purchase Logging, Monthly Fuel Report** — were **pulled forward and SHIPPED in v1.0 (builds 74–78)**. Their specs are kept here as the as-built reference; see "Where we left off" for the implementation summary. Everything from **Remote Fuel Prices** onward is still v1.1-planned.

### HEADLINE — GPS Trip Tracking (Start → Drive → End) — ✅ SHIPPED in v1.0 (builds 74–78)

The differentiator: record the **actual** drive and compare it to the estimate, then self-correct the vehicle's real-world efficiency.

- **Flow:** user calculates a trip → on the result sheet a new amber pill **"Start Tracking This Trip"** appears → app enters tracking mode with a **live dashboard** (distance so far, est. fuel burned, est. cost, time elapsed, current speed) → auto-detect arrival (**within 500 m** of destination) or user taps **"End Trip"** → **Trip Summary**: ESTIMATED vs ACTUAL (km / litres / PHP) + an accuracy % ("your estimate was 93% accurate") + the inferred real km/L for this route ("your Vios seems to get ~13.8 km/L, rated 14.5") + **[Update my profile] / [Keep current]**.
- **Update my profile** → adjust the vehicle's real-world km/L and feed REAL data into `DrivingProfile` (instead of self-reported), so the next same-route estimate is more accurate.
- **Technical:** `NSLocationAlwaysAndWhenInUseUsageDescription` = "aigos tracks your trip to compare estimated vs actual fuel cost. Location is stored on-device only."; `CLLocationManager` with `allowsBackgroundLocationUpdates`; battery-efficient — `kCLLocationAccuracyHundredMeters` + distance filter **50 m** (continuous for short trips, `startMonitoringSignificantLocationChanges` for long); store the route as `[CLLocationCoordinate2D]`; compute actual distance from GPS points; save to `TripRecord` with **`isTracked = true`**; show tracked trips in History with an **accuracy badge**.
- **Privacy (locked):** GPS data **never leaves the device** (no server/cloud); tracking is **opt-in per trip**; the user can delete any tracked trip. This EXTENDS the existing precise-location declaration to background use — update `PrivacyInfo.xcprivacy` + ASC nutrition labels (Location = App Functionality, not linked, not tracking).

### Fuel Purchase Logging (true km/L from fill-to-fill) — ✅ SHIPPED in v1.0

- **Flow:** a "Fuel Log" section (new area or inside History) → "Log Fuel Purchase" form: Date (default today), Station name (optional — Apple Maps search or manual), Fuel type (auto from vehicle), Litres purchased, Total cost (PHP), Odometer (km), **Full tank?** toggle (critical for fill-to-fill). After **2+ full-tank logs**: ACTUAL km/L = (odometer₂ − odometer₁) / litres₂ → "Your real efficiency: 12.8 km/L (rated 14.5, −12%)" → offer to update the vehicle profile.
- **Data model** (new `@Model` — remember to add to the `aigosApp` schema AND every `#Preview .modelContainer(for:)`):
  ```
  @Model class FuelLog {
      var id: UUID = UUID()
      var date: Date
      var vehicleId: UUID
      var stationName: String?
      var fuelType: FuelType
      var litersPurchased: Double
      var totalCostPHP: Double
      var odometerKm: Double?
      var isFullTank: Bool
      var pricePerLiter: Double
      var createdAt: Date = Date()
  }
  ```

### Monthly Fuel Report (shareable) — ✅ SHIPPED in v1.0

- Auto-generated on the 1st of each month: total spent, total trips, total distance, avg trip cost, avg km/L; most expensive / cheapest / most-frequent trip; **vs last month** deltas (fuel spend, fuel price, distance); one fuel-saving tip derived from the user's own history (e.g. "Friday evening drives cost 25% more than Monday mornings — rush-hour traffic"). Footer: "Made with aigos 🇵🇭".
- **Share:** render via **SwiftUI `ImageRenderer`/Canvas** to an image — Instagram Story (1080×1920), Facebook (text + image), screenshot-friendly; share via `UIActivityViewController`. All computed on-device from `TripRecord`/`FuelLog`.

### Remote Fuel Prices (auto-update, no app update)

- Host `prices.json` on **GitHub Pages** (free/static). A **GitHub Actions** cron (Tuesdays 08:00 Manila) scrapes the DOE weekly advisory from fuelprice.ph, updates `prices.json`, auto-commits. App on launch (when online): fetch → compare `lastUpdated` to local → if newer, silently update `FuelPriceCache`; if offline/failed, keep local; show an "Updated [date]" badge. **Never block launch**; the user can still override any price. This is the one pre-approved network exception from the spec (fuel-price fetch with cached fallback).
- Repo: `aigos-prices/prices.json` + `.github/workflows/update-prices.yml`. Format: `{ "lastUpdated": "YYYY-MM-DD", "source": "DOE via fuelprice.ph", "prices": { "unleaded91": 72.00, "premium95": 73.00, "premium97": 76.00, "diesel": 69.10, "premiumDiesel": 72.40, "eGasoline": 73.50 } }`.

### Gas Station Finder (online) — see also the earlier backlog note

- Online: `MKLocalSearch` with category `.gasStation` to find stations along the calculated route → map pins + a list with distance-along-route; filter by brand (Shell, Petron, Caltex, Seaoil, Phoenix, Flying V, Cleanfuel); sort by nearest / cheapest (if price data exists). In Talk: "Nearest gas stations on your route to Baguio: 1. Shell Dau — 2 km from NLEX exit … 3. Flying V Urdaneta — last station before the mountain climb." Offline: general advice only ("fill up before entering TPLEX; stations are sparse on the mountain section to Baguio"). Replaces the generic v1.0 refuel message when online.

### Widgets (WidgetKit + App Groups)

- Small (2×2): current fuel prices ("Unleaded 91: PHP 72.00"), updates weekly with the price fetch, tap → app. Medium (4×2): last-trip summary ("Home → Office — PHP 85") or month-to-date spend. Lock-screen: single current price ("⛽ PHP 72/L") with a trend arrow. Share data app↔widget via an **App Group**.

### Apple Watch companion

- Complications: current fuel price / last-trip cost / monthly spend. Watch app: **saved routes only** ("Home to Office: PHP 85 today", tap → breakdown) — no full calculator on the watch, just saved-route recalculation.

### v1.1 quality improvements

- Expand the offline gazetteer from **`UnlistedSearchLog`** analytics (already recording "not listed" searches locally).
- Offline **OSRM** road routing if the bundled PH extract fits under ~100 MB (else keep haversine×1.3 / MKDirections).
- **Apple Intelligence via FoundationModels** when the SDK is stable — flip the existing `AIAvailability` seam ON; keep the badge provider-neutral.
- **Conversation memory** in Talk to aigos (multi-turn context beyond the current per-message `lastQuery`).
- Vehicle **year-based variant** selection in the DB add flow.
- Crowdsourced fuel prices from users (opt-in; would need a backend — weigh against the zero-backend rule).
- **Dark-amber dark-mode** option; **iPad** support; full **accessibility audit** (VoiceOver, Dynamic Type, contrast).

## v2.0 Ideas (further out — not scoped)

- Android version (React Native or Kotlin).
- Fleet-management dashboard.
- Delivery-rider mode with per-delivery tracking.
- **OBD-II Bluetooth** integration for real-time fuel consumption.
- Carbon-footprint tracking.
- Fuel-price alerts (notify when prices drop).
- Route optimization: cheapest-fuel route vs fastest route.

## Skills & References
- UI/UX design system: see UI_GUIDELINES.md
- SwiftUI patterns: see skills/swiftui-design.md