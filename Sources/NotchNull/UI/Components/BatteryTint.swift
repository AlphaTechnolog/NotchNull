import SwiftUI

extension BatteryState {
    /// At or below this percentage the battery is red in every energy mode.
    static let criticalPercent = 10

    /// Battery color: red at 10% or less in any mode; otherwise the energy mode's color —
    /// orange in Low Power, green in Automatic (balanced), blue in High Power — plugged in or not.
    var tint: Color {
        if percent <= Self.criticalPercent { return Theme.Accent.danger }
        switch powerMode {
        case .low: return Theme.Accent.lowPowerMode
        case .automatic: return Theme.Accent.battery
        case .high: return Theme.Accent.highPower
        }
    }

    /// Accent for the charging bolt and HUD; the same rule as the battery itself.
    var chargeTint: Color { tint }

    var accessibilityDescription: String {
        var text = "Battery \(percent) percent"
        if isCharging { text += ", charging" }
        if powerMode != .automatic { text += ", \(powerMode.title) mode" }
        return text
    }
}
