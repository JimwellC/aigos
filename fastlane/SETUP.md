# Fastlane — aigos release automation

Automated TestFlight + App Store submission for `com.aigos.app`.

> `fastlane/README.md` is **auto-generated** by fastlane on every run (just the
> lane list). This file is the hand-written setup guide — edit this one.

Fastlane is installed via Homebrew (it vendors its own Ruby, so the system
Ruby 2.6 is not used). If `fastlane` isn't on PATH: `brew install fastlane`.

## One-time setup (needs YOUR Apple accounts)

1. **App Store Connect API key** (auth — no 2FA, works headless):
   - App Store Connect → *Users and Access* → *Integrations* → *App Store
     Connect API* → generate an **App Manager** key.
   - Download `AuthKey_XXXXXXXXXX.p8` **once** and move it somewhere outside
     the repo (e.g. `~/.appstoreconnect/private_keys/`).
   - `cp fastlane/.env.template fastlane/.env` and fill in `ASC_KEY_ID`,
     `ASC_ISSUER_ID`, `ASC_KEY_PATH`. (`.env` is gitignored.)

2. **Create the app record** in App Store Connect for `com.aigos.app`
   (name *aigos*, primary language English (U.S.)). `deliver` updates an
   existing record; it's simplest to create it once in the web UI.

3. **Replace the placeholder metadata** before pushing:
   - `fastlane/metadata/en-US/support_url.txt` → your real support URL
   - `fastlane/metadata/en-US/privacy_url.txt` → your hosted privacy policy
     (`docs/app-store/privacy-policy.md`)
   - `fastlane/metadata/review_information/phone_number.txt` → your number

4. **Set in App Store Connect by hand** (not managed by these files):
   - Category (listing suggests **Navigation**), age rating **4+**
   - Price tier (one-time paid, no IAP)
   - App Privacy nutrition labels — must mirror `PrivacyInfo.xcprivacy`:
     Location (Precise) → App Functionality, **not** linked, **not** tracking;
     everything else "Data Not Collected."

## Lanes

Run from the repo root:

| Command | What it does |
|---|---|
| `fastlane test` | Runs the unit-test suite on the iPhone 16 simulator. ✅ verified passing (111 tests). |
| `fastlane build` | Archives a signed App Store `.ipa` into `build/fastlane/` (no upload). |
| `fastlane beta` | Archives + uploads to **TestFlight** (internal). |
| `fastlane metadata` | Pushes only the listing text (name/subtitle/description/keywords/notes) — no binary. Good first dry run. |
| `fastlane release` | Archives + uploads binary **and** metadata to App Store Connect. Does **not** auto-submit — review the draft, then submit (or flip `submit_for_review: true` in the Fastfile). |

The build number is derived from `git` commit count and injected at build time
(`CURRENT_PROJECT_VERSION`), so it always increases without editing the
project. The marketing version stays `1.0` — bump `MARKETING_VERSION` in Xcode
for a new public version.

## Screenshots (not wired yet)

Drop 6.7" PNGs in `fastlane/screenshots/en-US/`, set `skip_screenshots(false)`
in `Deliverfile`, and they'll upload with `metadata`/`release`. Captions and the
recommended order are in `docs/app-store/listing.md`.

## Suggested first run

```bash
fastlane test          # green tests  (already verified)
fastlane metadata      # dry-run the listing push (no binary)
fastlane beta          # first TestFlight build — smoke-test on device
fastlane release       # push the App Store binary + metadata, then submit in ASC
```
