import SwiftUI
import UserNotifications

@main
struct OdometerApp: App {
    @State private var store: Store
    @State private var router = Router()
    @State private var pro: Pro
    init() {
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay")
        _store = State(initialValue: Store(demo: demo))
        // Screenshots and the review recording show Pro; the paywall shots show it locked.
        let shot = a.firstIndex(of: "-shot").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
        let lockedShot = shot.map { $0.hasPrefix("paywall") || $0.hasPrefix("locked") } ?? false
        _pro = State(initialValue: demo ? Pro(forced: !lockedShot) : Pro())
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(router).environment(pro).preferredColorScheme(.dark).tint(Dash.amber)
                .onAppear { router.applyShotArgs(store, pro); Autopilot.shared.run(store, router) }
        }
    }
}

enum Tab: String, CaseIterable {
    case car = "Car", due = "Due", fuel = "Fuel", log = "Log", costs = "Costs"
    var icon: String {
        switch self {
        case .car: return "car.side.fill"
        case .due: return "wrench.and.screwdriver.fill"
        case .fuel: return "fuelpump.fill"
        case .log: return "list.bullet.rectangle.fill"
        case .costs: return "chart.bar.fill"
        }
    }
}

enum Sheet: Identifiable {
    case vehicle(Vehicle), fuel(Fuel?), service(Service?), expense(Expense?), reading, history, settings, intervals
    var id: String {
        switch self {
        case .vehicle(let v): return "v" + v.id.uuidString
        case .fuel(let f): return "f" + (f?.id.uuidString ?? "new")
        case .service(let s): return "s" + (s?.id.uuidString ?? "new")
        case .expense(let e): return "e" + (e?.id.uuidString ?? "new")
        case .reading: return "reading"
        case .history: return "history"
        case .settings: return "settings"
        case .intervals: return "intervals"
        }
    }
}

@Observable
final class Router {
    var tab: Tab = .car
    var sheet: Sheet? = nil
    func applyShotArgs(_ s: Store, _ pro: Pro) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        switch a[i + 1] {
        case "due": tab = .due
        case "fuel": tab = .fuel
        case "log": tab = .log
        case "costs": tab = .costs
        case "history": tab = .car; sheet = .history
        case "add": tab = .fuel; sheet = .fuel(nil)
        case "paywall": tab = .costs; pro.ask(.costs)
        case "locked": tab = .costs
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        @Bindable var router = router
        @Bindable var pro = pro
        ZStack(alignment: .bottom) {
            DashBackground()
            Group {
                if store.vehicles.isEmpty {
                    EmptyGarage()
                } else {
                    switch router.tab {
                    case .car: CarView()
                    case .due: DueView()
                    case .fuel: FuelView()
                    case .log: LogView()
                    case .costs:
                        if pro.unlocked { CostsView() } else {
                            LockedPage(reason: .costs, title: "What does it really cost?", pitch: "Cost per month and per mile, where the money goes and twelve months of bars, from the fuel, services and bills you log.") { CostsView() }
                        }
                    }
                }
            }
            if !store.vehicles.isEmpty { DashTabBar(selection: $router.tab).padding(.bottom, 2) }
        }
        .sheet(item: $router.sheet) { s in
            Group {
                switch s {
                case .vehicle(let v): VehicleEditor(vehicle: v)
                case .fuel(let f): FuelEditor(fuel: f)
                case .service(let sv): ServiceEditor(service: sv)
                case .expense(let e): ExpenseEditor(expense: e)
                case .reading: ReadingSheet()
                case .history: HistorySheet()
                case .settings: SettingsSheet()
                case .intervals: IntervalsSheet()
                }
            }
            .presentationBackground(Dash.bg2).presentationDetents([.large]).presentationDragIndicator(.visible)
            .sheet(item: $pro.paywall) { r in PaywallView(reason: r).presentationBackground(Dash.bg) }
        }
        .sheet(item: Binding(get: { router.sheet == nil ? pro.paywall : nil }, set: { pro.paywall = $0 })) { r in PaywallView(reason: r).presentationBackground(Dash.bg) }
    }
}

struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) { content }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 110)
        }
    }
}

struct SheetPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.big(26)).foregroundStyle(Dash.cream).padding(.top, 22)
                content
            }.padding(.horizontal, 18).padding(.bottom, 40)
        }
    }
}

enum Reminders {
    static func sync(_ store: Store) {
        let c = UNUserNotificationCenter.current()
        c.removeAllPendingNotificationRequests()
        let want = store.vehicles.filter { $0.remind }
        guard !want.isEmpty else { return }
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            for v in want {
                for p in store.papers(v) where p.days > 14 {
                    let content = UNMutableNotificationContent()
                    content.title = v.title
                    content.body = "\(p.name) in 14 days, on \(Day.pretty(p.date))."
                    var dc = Day.cal.dateComponents([.year, .month, .day], from: Day.date(Day.add(p.date, -14))); dc.hour = 9
                    c.add(UNNotificationRequest(identifier: "odo-\(v.id)-\(p.id)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
                }
            }
        }
    }
}
