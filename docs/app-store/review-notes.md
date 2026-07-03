# App Review notes for aigos

> Paste into App Store Connect → App Review Information → "Notes."
> NOTE: written assuming one-time paid, no IAP. If shipping free or with IAP, edit the "Other" section.

```
Thank you for reviewing aigos.

WHAT IT IS
aigos is an offline fuel-trip cost calculator for Filipino drivers. Pick a vehicle,
enter a route, and it estimates the fuel cost using a physics-based model (speed,
aircon, road type, traffic, load). Prices are in Philippine pesos (PHP) and places
are Philippine locations (e.g., Manila, Batangas, NLEX) — this is expected and
correct for the target market.

NO ACCOUNT NEEDED
There is no login, sign-up, or paywall gate. All features are available immediately
on launch — no demo credentials are required to test the full app. First launch
shows a short onboarding to create a vehicle; you can also add one anytime.

OFFLINE-FIRST
The core app works with no internet connection: calculation, history, saved routes,
editable prices, and "Talk to aigos" (a natural-language trip parser) all run
entirely on-device. You can test the whole flow in Airplane Mode.

OPTIONAL LOCATION / MAPS
There is ONE optional enhancement that uses the network: the map location picker.
- It appears only when the user taps the small map button on a route field.
- Tapping "Use my location" requests When-In-Use location permission at that moment
  (never at launch). If permission is declined, the picker still works via search
  and by dropping a pin.
- It uses Apple's MapKit (map tiles, MKLocalSearch, MKDirections) to show the map
  and, when online, a precise road distance labeled "via Apple Maps." Offline, the
  app falls back to a labeled estimate. No third-party map services are used.

PRIVACY
aigos collects no data and has no backend/servers/analytics/ads/tracking. Location
is used only on-device to set a starting point and is never stored, shared, or
linked to identity. The bundled PrivacyInfo.xcprivacy declares Precise Location as
"App Functionality" (not linked, not used for tracking), and the App Privacy
nutrition labels mirror this.

OTHER
- One-time paid app: no in-app purchases or subscriptions.
- Uses only standard/exempt encryption (HTTPS via Apple frameworks);
  ITSAppUsesNonExemptEncryption = NO is declared.
- iPhone only, portrait, iOS 17+.

Maraming salamat!
```
