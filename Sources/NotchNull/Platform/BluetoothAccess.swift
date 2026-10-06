import Foundation

/// The first IOBluetooth call of a launch waits for macOS to settle the Bluetooth permission,
/// which it asks for again after every update. Made on the main thread, that wait froze launch
/// before any window existed. The first call is made here, off the main thread; everything that
/// needs IOBluetooth on the main thread (it delivers notifications there) waits for it.
@MainActor
enum BluetoothAccess {
    private typealias GetPower = @convention(c) () -> Int32
    private static let getPower: GetPower? = {
        guard let handle = dlopen("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_LAZY),
              let symbol = dlsym(handle, "IOBluetoothPreferenceGetControllerPowerState") else { return nil }
        return unsafeBitCast(symbol, to: GetPower.self)
    }()
    private static var reading = false
    private static var answered = false
    private static var afterAnswer: [@MainActor () -> Void] = []

    /// Reads whether Bluetooth is on without blocking the main thread. A read already waiting
    /// on the permission prompt covers this one, so it is skipped.
    static func readPower(_ completion: @escaping @MainActor (Bool) -> Void) {
        guard let get = getPower, !reading else { return }
        reading = true
        DispatchQueue.global(qos: .utility).async {
            let isOn = get() != 0
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    reading = false
                    answered = true
                    completion(isOn)
                    let waiting = afterAnswer
                    afterAnswer = []
                    waiting.forEach { $0() }
                }
            }
        }
    }

    /// Runs `action` on the main thread once IOBluetooth has answered its first call.
    static func whenAnswered(_ action: @escaping @MainActor () -> Void) {
        guard getPower != nil, !answered else {
            action()
            return
        }
        afterAnswer.append(action)
        readPower { _ in }
    }
}
