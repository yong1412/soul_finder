# Google Maps & Public Transport Integration for MapRadarView

This plan outlines the steps to integrate Google Maps into the `MapRadarView`, show real-time device location, and display nearby public transport stations (Bus, LRT, MRT) with a radar overlay.

## User Review Required

> [!IMPORTANT]
> **Google Maps API Key**: You will need to provide a valid Google Maps API Key for both Android and iOS. I will add placeholders where these keys should be placed.
>
> **Permissions**: The app will request Location permissions from the user. I will handle the logic for requesting and checking these permissions.

## Open Questions

- Do you have a specific API or service for public transport station data? If not, I will implement a mock service that generates stations near your current location for testing purposes.
- Would you like the radar sweep animation to be overlaid on top of the Google Map, or should they be separate modes? (I'll assume overlay for a more "integrated" feel).

## Proposed Changes

### Configuration & Dependencies

#### [MODIFY] [pubspec.yaml](file:///C:/Users/ahbla/OneDrive/Documents/GitHub/soul_finder/pubspec.yaml)
- Add `google_maps_flutter` for map integration.
- Add `geolocator` for real-time location tracking.

#### [MODIFY] [AndroidManifest.xml](file:///C:/Users/ahbla/OneDrive/Documents/GitHub/soul_finder/android/app/src/main/AndroidManifest.xml)
- Add `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` permissions.
- Add Google Maps API Key meta-data.

#### [MODIFY] [Info.plist](file:///C:/Users/ahbla/OneDrive/Documents/GitHub/soul_finder/ios/Runner/Info.plist)
- Add `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysUsageDescription`.

---

### Core Services

#### [NEW] [location_service.dart](file:///C:/Users/ahbla/OneDrive/Documents/GitHub/soul_finder/lib/services/location_service.dart)
- Handle permission requests.
- Provide a stream of real-time location updates.

#### [NEW] [transport_service.dart](file:///C:/Users/ahbla/OneDrive/Documents/GitHub/soul_finder/lib/services/transport_service.dart)
- Define `Station` model (Bus, LRT, MRT).
- Fetch or mock nearby stations based on coordinates.

---

### UI Components

#### [MODIFY] [map_radar_view.dart](file:///C:/Users/ahbla/OneDrive/Documents/GitHub/soul_finder/lib/views/map_radar_view.dart)
- Integrate `GoogleMap` widget.
- Update the `CustomPainter` to handle map-relative positions if possible, or maintain the radar as an aesthetic overlay.
- Display markers for nearby stations.
- Sync map camera with real-time location.

## Verification Plan

### Automated Tests
- Unit tests for `LocationService` (mocking Geolocator).
- Unit tests for `TransportService` data parsing.

### Manual Verification
- Verify that the app asks for location permission on first launch of the Radar screen.
- Verify that the map centers on the current device location.
- Verify that markers for Bus/LRT/MRT stations appear on the map.
- Verify that the radar sweep animation still functions as an overlay.
