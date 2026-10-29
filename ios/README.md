# Weather Atlas for iOS and web

Native SwiftUI + MapKit iOS app and a standalone web app at https://puneetvrma.github.io/weather/.

## Install on iPhone

1. Clone or download this repository and open `ios/WeatherAtlas.xcodeproj` in Xcode 16 or newer.
2. Select the WeatherAtlas target, then Signing & Capabilities. Select your own development team and change the bundle identifier to a unique value.
3. Choose your iPhone or an iOS 17+ simulator and run. A personal Apple ID can be used for development subject to Apple's provisioning limits. TestFlight/App Store distribution requires the appropriate Apple developer membership, signing, app metadata and review process.

The app uses native SwiftUI screens, Core Location and MapKit, not a web-view wrapper. No API keys, paid services, or backend are needed for this personal version. The project deliberately contains no developer identity or signing secrets. A signed IPA is not provided.

## Features

- Worldwide city search and optional device location.
- Rain and temperature model maps spanning seven hourly steps, from the next hourly forecast through six hours later.
- Observed radar animation for approximately the preceding two hours, where radar coverage is available.
- A 7 × 7 forecast sampling grid around the selected location, approximately 15 km between samples; hourly precipitation and temperature cards.
- Explicit data retrieval times, radar frame ages, and unavailable-data states.
- Ten-minute forecast caching during a session. Manual refresh reuses recent data to protect public API quotas.

## Data, accuracy and resolution

The six-hour future precipitation layer is a numerical weather forecast. It is **not** a six-hour radar nowcast. No global, high-resolution, six-hour public radar nowcast is bundled. Forecast model and native resolution vary by region under Open-Meteo's best-match endpoint. The 15 km displayed sampling interval is a client choice, not a claim of 15 km model accuracy. The grids deliberately show cells instead of fabricated fine detail. Actual model coordinates may be snapped by the provider to a nearby native grid cell.

RainViewer's current free service supplies historical radar and restricts native tiles to zoom 7. Higher zooms enlarge the same source detail. Empty radar tiles can indicate no precipitation, missing coverage or a source outage. Radar frames combine observations from different measurement times. App display times are in the device timezone. Hourly precipitation is the accumulation over the hour ending at the timestamp. The first time is the next available whole-hour step, so the timeline extends at least six hours into the future.

- Forecast: https://open-meteo.com/en/docs — public endpoint for non-commercial personal use. Each batch contains 49 locations; providers may count each location toward quotas. Do not poll aggressively or use this static prototype as a high-traffic public weather service without arranging capacity and caching.
- Radar: https://www.rainviewer.com/api/weather-maps-api.html and https://www.rainviewer.com/api/transition-faq.html — personal/educational use, no uptime guarantee.
- Web base map: OpenStreetMap, standard tile usage policy; no bulk downloading or offline map prefetching. Native base map: Apple Maps.

## Privacy

Searching sends the query to Open-Meteo geocoding. Loading weather sends selected coordinates to Open-Meteo; map viewport and network address are visible to map/radar providers. Device location is used only after permission. There is no app analytics, account system, or server-side location store. The web app caches recent forecasts in sessionStorage, and iOS caches recent selections in memory and may use standard URLSession HTTP caching.

## Validation

The repository workflow builds the native app for a generic iOS simulator without signing. Run locally with:

```sh
xcodebuild -project ios/WeatherAtlas.xcodeproj -scheme WeatherAtlas -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The authoring environment has no Xcode or Swift toolchain, so local simulator, hardware, signing, and visual native validation must be performed with Xcode. The GitHub workflow build result is the source of truth for compilation, not the presence of these sources.

Web app: serve the repository root using an HTTP server and open `/weather/`. No build step. Internet access is required for Leaflet, map tiles, search and weather APIs. `weather/core.js` contains testable pure calculations. The existing academic site remains the root site; this app is a separate directory.
