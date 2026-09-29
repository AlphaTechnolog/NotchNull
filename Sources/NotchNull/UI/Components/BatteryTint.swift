import SwiftUI

extension BatteryState {
    /// Battery color, following the energy mode like the macOS menu bar:
    /// yellow in Low Power, orange in High Power, green while charging, red when nearly empty.
    var tint: Color {
        switch powerMode {
        case .low: return Theme.Accent.lowPower
        case .high: return Theme.Accent.highPower
        case .automatic: break
        }
        if isPluggedIn { return Theme.Accent.battery }
        if percent <= 20 { return Theme.Accent.danger }
        return .white
    }

    /// Accent for the charging bolt and HUD: the energy mode color, or green.
    var chargeTint: Color {
        powerMode == .automatic ? Theme.Accent.battery : tint
    }

    var accessibilityDescription: String {
        var text = "Battery \(percent) percent"
        if isCharging { text += ", charging" }
        if powerMode != .automatic { text += ", \(powerMode.title) mode" }
        return text
    }
}
