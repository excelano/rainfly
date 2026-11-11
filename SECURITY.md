# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately, using the **Report a vulnerability** button on the Security tab of this repository. If that button is not there, or you would rather not go through GitHub, email david.anderson@excelano.com instead. I aim to respond within seven days.

Please do not open public issues for security problems.

## Supported versions

The latest release receives security fixes. Older versions are not supported. A fix ships in a new App Store release.

## What Rainfly can access

Rainfly talks only to Apple's services. Forecasts come from WeatherKit, which the phone and the watch each reach through the system with Apple's own authentication. Adding a camp asks Apple's map service for a place name and time zone at the camp's coordinates, a camp search sends the typed text to the same service, and the iPhone's map for placing a camp is drawn by it. While the dew diary and its sharing are on, answered diary nights go to the public database of Excelano's CloudKit container, whose security roles let a signed-in iCloud user create records and only a record's creator read, change or delete it; the public cannot read them. The app opens no other connection and links no analytics or tracking code.

It reads location only with permission, and sends it only to Apple. A coarse position is read while the app is on screen, after the system asks for permission, and goes to Apple's weather service as the place to forecast, or to Apple's map service when it becomes a saved camp. It is not stored apart from the forecast fetched for it and the camps you save. With the pressure alert on, it reads the barometer on background refreshes through the night.

## What Rainfly stores

Fetched forecasts, saved camps, the trip, the settings and the last twelve hours of overnight barometer readings are kept on each device in an App Group container shared by the app and its widgets or complication, so verdicts work without a connection. The iPhone also keeps the dew diary's nights, forecasts and answers. With both apps installed, the saved camps, the trip, the camp being shown, the settings and the forecasts for saved camps pass between the iPhone and its paired watch through WatchConnectivity; My Location, its forecasts and the barometer readings stay on the device that took them. The pressure warning is a local notification raised on the device itself. Removing the app removes all of it from that device. Shared diary nights carry no camp names, a position rounded to 0.1° and a random diary ID; the diary screen deletes them from the database.
