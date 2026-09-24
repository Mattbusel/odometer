import SwiftUI

/// Drives the real screens for the App Review recording (-demoAutoplay).
@Observable
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private var running = false
    @MainActor private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
    @MainActor
    func run(_ store: Store, _ router: Router) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(3)
            if let v = store.car { withAnimation { store.setMiles(v, store.miles(v) + 187) } }
            await wait(3)
            router.tab = .due; await wait(4)
            router.tab = .fuel; await wait(2.5)
            router.sheet = .fuel(nil); await wait(3)
            router.sheet = nil; await wait(0.8)
            if let v = store.car { withAnimation { store.fuel.append(Fuel(vehicle: v.id, date: Day.today, miles: store.miles(v), gallons: 11.2, price: 41.38, full: true)) } }
            await wait(3)
            router.tab = .log; await wait(3.5)
            router.tab = .costs; await wait(4)
            router.tab = .car; await wait(1.5)
            router.sheet = .history; await wait(4)
            router.sheet = nil; await wait(1)
            try? Data("ok".utf8).write(to: URL.documentsDirectory.appending(path: "demo_done"))
        }
    }
}
