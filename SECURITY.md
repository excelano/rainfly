# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately through GitHub Security Advisories at https://github.com/excelano/zeltwetter/security/advisories/new. If you would rather not use GitHub, email david.anderson@excelano.com instead. I aim to respond within seven days.

Please do not open public issues for security problems.

## Supported versions

Only the latest version on the App Store receives fixes. Security fixes ship through `main` and reach the App Store in the next release; there are no maintained release branches. A repository with no releases is supported at its default branch.

## Security model

**Zeltwetter talks only to Apple's weather service.** Forecasts come from WeatherKit, which the watch reaches through the system with Apple's own authentication. The app opens no other connection and links no analytics or tracking code.

**It reads location only with permission, and sends it only to WeatherKit.** A coarse position is read while the app is on screen, after watchOS asks for permission, and goes to Apple's weather service as the place to forecast. It is not stored apart from the forecast fetched for it.

**What it keeps stays on the watch.** Fetched forecasts and the settings are kept in an App Group container shared by the watch app and its complication, so verdicts work without a connection. Removing the app removes them.
