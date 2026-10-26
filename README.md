# Zeltwetter

Zeltwetter answers one question at camp: should the rain fly go on tonight? It reads the night's forecast for your campsite and gives a yes or no with the reason, such as "Dew likely by 4 AM" or "Rain 35% after 2 AM", and in the morning it estimates when the tent will be dry enough to pack. It runs on Apple Watch alone, with no iPhone app, no account, no ads and no analytics.

It is deliberately narrow. There is no radar, no map, no hourly chart and no week ahead, only what tonight means for your gear.

## Using it

The main screen shows the verdict for tonight, or for this morning between sunrise and the time you plan to break camp. "Fly on" means at least one check fired, and the line under it names the one that matters most and when. "Fly off" means every check is clear. Notes below that suggest opening the vents when the fly is on and the air is damp or still, warn when the night will be colder than your sleeping bag's comfort rating, and give the time the tent should be dry. The footer names the camp and the age of the forecast, which turns orange after twelve hours and red after a day. Tapping the verdict lists every check with its time and the night's low, closest dew-point spread and highest rain chance.

The checks are independent, and any one of them puts the fly on: thunderstorms overnight or before you break camp, rain during the night, rain carried by strong wind, frost or dew on a clear and calm night, rain in the morning before you pack, and a cold night. Each threshold can be changed in Settings, along with the units, the break-camp time and the bag rating, and Reset to defaults puts the thresholds back.

Forecasts are fetched while the watch has a connection and kept on it, so the verdict holds in the backcountry. The list button at the top left of the main screen manages camps. Here is the watch's own position. A camp can be added by searching for a campground, park, town or address, from the watch's current position, or by entering coordinates in degrees and decimal minutes with the Digital Crown. Tapping a camp shows it tonight. The trip plans a camp for each night ahead, the main screen and complication switch to it each evening, and Download trip fetches every night within a week so they are ready when the signal is gone.

A complication shows the verdict on the watch face in the circular, corner, rectangular and inline slots, and switches to the dry-by time in the morning. With the pressure watch on, the watch reads its barometer on each background refresh through the night and sends a notification when the pressure falls fast while the fly is off. watchOS grants an app only a few background refreshes an hour, more when its complication is on the active face, so this is coarse sampling rather than continuous monitoring.

## Building

Open `Zeltwetter.xcodeproj` in Xcode. The `Zeltwetter Watch App` scheme builds the watch app for a watch or the simulator and runs the tests. The `Zeltwetter` scheme builds and archives the iPhone app, which embeds the watch app. Code both apps use lives in `Shared/`, the watch's own in `Watch/` and the phone's in `Phone/`. The complication is its own extension target, `ZeltwetterWidgets` in `WatchWidgets/`, which shares the forecast cache and settings with the watch app through an App Group.

The identity a fork changes, meaning the team id, the bundle ids, the App Group and the display name, lives in `Config/Zeltwetter.xcconfig`, and the version in `Config/Version.xcconfig`. The App ID needs the WeatherKit capability and service and the App Group. The project has no dependencies beyond Apple's frameworks.

The rule engine in `Shared/Engine` uses Foundation alone and is covered by the tests. A Debug build launched with `--demo` and one of `clear`, `rain`, `storm`, `dew` or `frost` replaces WeatherKit and the location with a fixed two-night trip whose first night gives that verdict, and `--open detail`, `--open settings` or `--open camps` also opens that screen; `Shared/Support/Demo.swift` has the details.

## Privacy

Zeltwetter sends a camp's position to Apple's WeatherKit for its forecast, and to Apple's map service when a camp is added or searched for. It reads your location while it is on screen, with permission, and the barometer during the night when the pressure watch is on. Forecasts, camps, the trip, settings and recent pressure readings stay on the watch. The privacy policy is at https://excelano.com/legal/#zeltwetter.

## License

MIT. See [LICENSE](LICENSE).
