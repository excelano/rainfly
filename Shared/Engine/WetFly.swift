// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

struct WetFly: Equatable, Sendable {
    let cause: Trigger
    let since: Date

    static func at(
        _ now: Date, night: NightForecast, current: CurrentConditions?, settings: Settings,
        dryByModel: DryByModel = DryByModel()
    ) -> WetFly? {
        var wet: WetFly?
        var drying: TimeInterval = 0
        func wetted(by cause: Trigger, at date: Date) {
            if wet.map({ cause.priority < $0.cause.priority }) ?? true { wet = WetFly(cause: cause, since: date) }
            drying = 0
        }

        let passed = NightWindow(night, packByMinutes: settings.packByMinutes).nightHours
            .filter { $0.date.addingTimeInterval(3600) <= now }
        for hour in passed {
            if let cause = cause(rained: hour.precipAmountMM > 0, spreadC: hour.spreadC, cloudCover: hour.cloudCover,
                                 windMS: hour.windMS, tempC: hour.tempC, settings: settings) {
                wetted(by: cause, at: hour.date)
            } else if wet != nil, dryByModel.driesAtNight(hour) {
                drying += 3600
                if drying >= dryByModel.nightDryingTime { wet = nil }
            } else {
                drying = 0
            }
        }
        if let current, current.date <= now,
           let cause = cause(rained: current.isRaining, spreadC: current.spreadC, cloudCover: current.cloudCover,
                             windMS: current.windMS, tempC: current.tempC, settings: settings) {
            wetted(by: cause, at: current.date)
        }
        return wet
    }

    private static func cause(
        rained: Bool, spreadC: Double, cloudCover: Double, windMS: Double, tempC: Double, settings: Settings
    ) -> Trigger? {
        if rained { return .rain }
        guard FlyEngine.condenses(spreadC: spreadC, cloudCover: cloudCover, windMS: windMS, settings: settings) else { return nil }
        return FlyEngine.isFrostAir(tempC) ? .frost : .dew
    }
}
