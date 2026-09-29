import AppKit

/// Plays the handwritten hello when the app launches and whenever the screen is unlocked.
@MainActor
final class HelloService {
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.greet() }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.greet() }
    }

    func greet() {
        guard Preferences.shared.sayHello else { return }
        ActivityCenter.shared.post(.hello, for: Constants.Durations.hello)
    }
}
