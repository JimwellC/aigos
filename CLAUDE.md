# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

**Sprints 1–3 built.** The `aigos.xcodeproj` app exists and builds warning-clean (Swift 6, iOS 17+); `aigos_architecture.pdf` remains the source-of-truth spec. Real jeepney mascot art is in place — **two** mascots, both delivered as source PNGs with a transparency-checker baked in as opaque pixels (strip it to real alpha with a scratchpad PIL/AppKit pass, never ship the raw checker): (1) `mascot.png` → front-facing badge in `Mascot.imageset`, used via `MascotView(imageName:"Mascot")` for the splash (168), Calculate header (44), Talk avatar (44), onboarding chat bubble (40); (2) `mascot_wave.png` → a **waving** jeepney (checker stripped + cropped) in `MascotWave.imageset`, used for the onboarding welcome hero and the subtle per-tab background watermark. `MascotView` takes `imageName` (default `"Mascot"`), plus `floatDistance`/`floatDuration` for the bob. The **app icon** is regenerated (scratchpad PIL) from `mascot_wave.png` — 85% scale, bled off the bottom-right, over a diagonal `#F5C97A→#C4793A` amber gradient, opaque 1024² no-alpha. The **wave background watermark** rides in `AigosBackground`'s opt-in `mascotPeek: CGSize?` param (rendered inside the orb `.overlay` so it can't inflate layout — same rule as the bokeh orbs), 300pt @ opacity 0.20, `.bottomTrailing`, on all 5 tab roots only (Calc 60/-70, History 65/-80, Saved 55/-75, Prices 60/-70, Settings 60/-80). `MascotEmptyState` is **text-only** (the tab watermark supplies its mascot — don't re-add a peek there or it doubles). Onboarding is now 4 steps: **0 = welcome hero** (large centered `Mascot`, 220pt, ±8pt/2.5s float), 1 = add vehicle, 2 = driving, 3 = prices; the progress bar is hidden on step 0. Don't reintroduce the `bus.fill` placeholder. Done: 5-tab shell with a custom **floating pill** tab bar (`AigosTabBar` — icon-only, amber `matchedGeometryEffect` indicator), SwiftData models, physics `CalculationEngine`, editable prices (tap-to-edit inline rows), trip history with month-over-month comparison + stats, saved routes with one-tap recalc, the self-learning `ProfileLearningEngine`, first-launch onboarding, animated splash + static launch screen, and "Talk to aigos" natural-language trip queries with an offline **vehicle knowledge base** (`TalkToAigosView` + `VehicleDatabaseService`). The whole UI follows the glassmorphism design system (see `UI_GUIDELINES.md` / `skills/swiftui-design.md`) built in `Support/DesignSystem.swift`. Reusable **native** animation primitives live in `Support/Animations.swift` (`staggeredAppear(index:)`, `PressableStyle`, `Shake`); count-ups use `contentTransition(.numericText)` driven by a spring. No third-party animation libraries — and note `Animatable.animatableData` can't be a stored property on a `@MainActor` `View` under Swift 6, so use `contentTransition`/`GeometryEffect` instead. An `aigosTests` unit-test target covers the pure logic (**206 cases**, all passing). Real app-icon + mascot art are done. Distances are gazetteer haversine×1.3 estimates offline, upgraded to precise `MKDirections` road distance when the optional map picker is used online (see the map/privacy notes below).

**Talk to aigos (v1.0 = offline parser only):** NL understanding runs through `TripQueryParser`, a deterministic offline parser that works on every device. Per the v1.0 product decision, the UI is **provider-neutral** — no "Apple Intelligence" or device-requirement wording anywhere (badge reads "On-device · works offline"). A seam for a real on-device system model is kept behind `#if canImport(FoundationModels)` in `AIAvailability` for v1.1 (this Xcode 16.4 / iOS 18.5 SDK doesn't ship the framework, so it's excluded now). Don't reintroduce Apple Intelligence framing in the UI or add `import FoundationModels` outside that guard.

**Routing (v1.0 = autocomplete-validated places → estimated distance):** places come from `GazetteerData.entries` (rich `GazetteerEntry`: title, province subtitle, coordinate, aliases like "BGC"/"EDSA"/"QC"). `GazetteerRouteResolver` derives an `index` (key + every alias → entry) and resolves via `lookup`/`entry(for:)`. `PlaceSearch.suggestions(...)` powers the `PlaceField` autocomplete (personal places first, then gazetteer, max 5); `PlaceSearch.exactKey(...)` is the validation gate (random text like "J" → nil). **`CalculateView` requires both origin AND destination selected from the dropdown** (`originKey`/`destinationKey` non-nil) before Calculate enables; distance is derived from the two picked places (haversine×1.3), OR the precise `MKDirections` road distance when a place is set via the map picker while online. `PlaceResolver` still resolves personal aliases before the gazetteer for `TripQueryParser`/Talk, and now also decodes map-picked `@pin:lat,lon` selection keys. **Personal places are now map-pinned:** `PersonalPlace` stores a precise `latitude`/`longitude` + reverse-geocoded `displayName` (legacy `gazetteerKey` still honored as a fallback), set via the center-pin `PlaceMapPicker` (Settings → Edit Place — the old city list is gone). `PlaceResolver.point` returns a personal place's exact `geoPoint` first, so using "Home"/"Office" in the calculator uses precise coordinates. Offline-safe: if reverse geocode fails the coordinate still saves and `mappedLabel` shows `lat, lon`. Manual free-text distance entry was removed in favour of validated place selection. The optional `LocationPickerView` (MapKit) lets users search/drop a pin; it's additive — the gazetteer estimate is the offline fallback. The gazetteer is built with `Dictionary(uniquingKeysWith:)` so a duplicate key can't crash launch; `lookup` is deterministic (longest contained key).

## Where we left off (session end · 2026-07-04, session 3)

**State:** builds warning-clean (Swift 6, iOS 17+), **206 tests passing**, everything committed + pushed to `github.com/JimwellC/aigos` (private, `main`).

**⚠️ BLOCKER for TestFlight / App Store upload — needs a toolchain update.** `fastlane beta` was run and got all the way through: **archive ✓, code-signing ✓** (distribution cert works — no cert/profile errors), **API-key auth ✓**, reached the App Store Connect app record (App ID `6787352080`). Apple then **rejected the upload with a 409 "SDK version" error**: apps must now be built with the **iOS 26 SDK (Xcode 26+)**. This Mac is on **Xcode 16.4 / iOS 18.5 SDK** (older macOS). **You must update to macOS 26 + Xcode 26 before `fastlane beta`/`release` can upload — no code changes are needed, only the toolchain.** After updating: `sudo xcode-select -s /Applications/Xcode.app` → `xcodebuild -version` (confirm 26.x) → re-run `fastlane beta`. Heads-up: on the iOS 26 SDK the `#if canImport(FoundationModels)` seam in `AIAvailability` flips to *active* (it's compiled out on 18.5) — after the first Xcode-26 build, confirm the Talk badge / `AIGateView` still read "On-device · works offline" with no Apple-Intelligence framing (the v1.0 decision).

**Fastlane — COMPLETE & WORKING** (only the SDK gate above blocks the actual upload). Installed via Homebrew (vendors its own Ruby; system Ruby 2.6 is too old). `fastlane/` has `Appfile` (bundle `com.aigos.app`, team `MWJJ994KSX`), `Fastfile` lanes — `test` / `build` / `beta` (TestFlight) / `release` (App Store, no auto-submit) / `metadata` / `verify` (read-only ASC auth check) — authed by an **App Store Connect API key configured in `fastlane/.env`** (gitignored; template in `.env.template`). Build number = git commit count injected at build time (`CURRENT_PROJECT_VERSION` via xcargs). `deliver` metadata is wired from `docs/app-store/` into `fastlane/metadata/`. `fastlane/SETUP.md` is the human guide; `fastlane/README.md` is auto-generated. Analytics opted out.

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

- **Privacy (locked declaration).** `NSPrivacyTracking = false`. The app collects **no** data on its own servers (there are none). The map picker requests **precise location only when the user taps the map button**, uses it purely on-device to set a starting point, and never stores/transmits/links it. `PrivacyInfo.xcprivacy` declares Precise Location as `AppFunctionality`, **not linked to identity, not used for tracking**; plus the one required-reason API (`UserDefaults`, `CA92.1`). App Store Connect nutrition labels must mirror this: Location → App Functionality, not linked, not tracking. Do not add data collection, tracking SDKs, or an ATT prompt.
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

**Toll + expressway knowledge:** `Resources/TollDatabase.json` (TRB-approved 2026 Class-1 rates via expressway.ph — 12 expressways with segments, 12 common full routes, RFID systems). `KnowledgeBase` answers toll lookups ("toll to Baguio" → route toll + the mandatory Class-1 note + "verify at expressway.ph" disclaimer), RFID load/which-RFID, MMDA number coding, and expressway emergency contacts — all checked **before** the route-facts/trip intents (toll shares the "toll" keyword). **Vehicle DB is now 235 entries** including **13 EVs** (`fuel:"electric"`, `VehicleEntry.isElectric`); EV answers report **km/kWh** and skip the litre-based "Use this efficiency" button (the trip calculator is petrol/diesel-priced — EV cost is out of scope). Note: the request's `RealWorldModifiers.json` duplicated the existing `RealWorldEfficiencyDatabase.json`, so that file was extended (clogged injectors, cruise control) rather than duplicated. Covered by `VehicleDatabaseTests`, `TalkResponderTests`, `KnowledgeBaseTests` (**206 tests total**).

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

Tests (**206 cases** covering the pure logic — `CalculationEngine` (incl. efficiency modifiers), `ProfileLearningEngine`, `TripQueryParser`, `GazetteerRouteResolver`, `FuelUnit`, `VehicleDatabase`, `KnowledgeBase`, `TalkResponder`, vehicle deletion, formatting, `MonthGroup`):

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

The `aigosTests` target covers the pure logic (**206 cases**, all passing) — run it with the `test` command above or `fastlane test`.

## Roadmap (Section 20)

- **Sprint 1 (default start):** Xcode + SwiftData `ModelContainer` setup, TabView skeleton, the four SwiftData models, an **OSRM prototype** (do this first), `CalculateView` (origin/destination input, vehicle picker, result card), `CalculationEngine`, editable `PricesView`. *Done when:* a user can pick a vehicle, enter origin + destination, tap calculate, and see a PHP fuel cost.
- **Sprint 2:** auto-save trips → `HistoryView` with month-over-month comparison, `SavedRoutesView`, `SettingsView`, 3-screen onboarding, app icon + jeepney mascot assets.
- **Sprint 3:** Apple Intelligence / `TalkToAigosView`, `AIGateView`, App Store assets + submission.

When starting fresh, default to Sprint 1 unless told otherwise. Keep scope tight — feature creep is the named enemy; ship imperfect and iterate.

## Skills & References
- UI/UX design system: see UI_GUIDELINES.md
- SwiftUI patterns: see skills/swiftui-design.md