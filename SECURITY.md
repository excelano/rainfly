# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately through GitHub Security Advisories at https://github.com/excelano/zeltwetter/security/advisories/new. If you would rather not use GitHub, email david.anderson@excelano.com instead. I aim to respond within seven days.

Please do not open public issues for security problems.

## Supported versions

The latest release receives fixes. A security fix ships through `main` in a new release on GitHub and, where the app is listed on the App Store, through it; there are no maintained release branches.

## Security model

**Zeltwetter talks only to Apple's services.** Forecasts come from WeatherKit, which the watch reaches through the system with Apple's own authentication. Adding a camp asks Apple's map service for a place name and time zone at the camp's coordinates, and a camp search sends the typed text to the same service. The app opens no other connection and links no analytics or tracking code.

**It reads location only with permission, and sends it only to Apple.** A coarse position is read while the app is on screen, after watchOS asks for permission, and goes to Apple's weather service as the place to forecast, or to Apple's map service when it becomes a saved camp. It is not stored apart from the forecast fetched for it and the camps you save.

**What it keeps stays on the watch.** Fetched forecasts, saved camps, the trip, the settings and the last twelve hours of overnight barometer readings are kept in an App Group container shared by the watch app and its complication, so verdicts work without a connection. The pressure warning is a local notification raised on the watch itself. Removing the app removes all of it.
