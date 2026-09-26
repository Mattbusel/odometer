import SwiftUI
import StoreKit

/// Odometer Pro: one non-consumable. Keeping one car on schedule is free forever; Pro is the
/// whole garage and the paperwork.
///
/// Free: one vehicle, the maintenance schedule and reminders, fuel and economy, the service and
/// expense log, the glovebox dates. Pro: more vehicles, the Costs tab, the service history PDF
/// and the CSV export.
///
/// Anyone who first installed a build before Pro existed keeps everything. AppTransaction's
/// originalAppVersion is the build number they first installed. Only trusted in production:
/// sandbox and Xcode report made-up values, and App Review must see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.odometer.pro"
    /// The first build that has Pro in it. Anything earlier had every feature.
    static let firstFreemiumBuild = 2

    enum Reason: String, Identifiable { case costs, garage, history, export, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    private var updates: Task<Void, Never>?
    private let key = "odometer.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$4.99" }

    func ask(_ why: Reason) { if !unlocked { paywall = why } }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - Paywall: the dashboard, with the Pro warning light on

struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var sweep = 0.0

    var body: some View {
        ZStack {
            DashBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Plate(text: "PRO")
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Dash.grey)
                                .frame(width: 38, height: 38).background(Circle().fill(Dash.card))
                        }.buttonStyle(.plain).accessibilityLabel("Close")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline).font(.big(32)).foregroundStyle(Dash.cream).fixedSize(horizontal: false, vertical: true)
                        Text("Keeping a car on schedule stays free forever. Pro is the whole garage and the paperwork.")
                            .font(.ui(15, .medium)).foregroundStyle(Dash.grey).fixedSize(horizontal: false, vertical: true)
                    }
                    gauges
                    VStack(alignment: .leading, spacing: 14) {
                        feature("car.2.fill", "Every vehicle", "The daily driver, the truck, the bike, the second car. Each with its own schedule.")
                        feature("chart.bar.fill", "Costs", "Cost per month and per mile, where the money goes, twelve months of bars.")
                        feature("doc.text.fill", "Service history PDF", "The document a buyer asks for. Every service, dated, with the mileage.")
                        feature("tablecells", "CSV export", "Every fill-up, service and expense, for a spreadsheet or an accountant.")
                    }.tile()
                    priceBlock
                    if let m = pro.message {
                        Text(m).font(.ui(13, .semibold)).foregroundStyle(Dash.amber).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    AmberButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill") {
                        Task { await pro.buy() }
                    }.disabled(pro.busy)
                    HStack {
                        GreyButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        Spacer()
                        GreyButton(title: "Not now") { dismiss() }
                    }
                    Text("One payment, yours for good. No subscription. Family Sharing works. Everything you have logged stays yours, Pro or not.")
                        .font(.ui(11.5, .medium)).foregroundStyle(Dash.dim).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.spring(duration: 1.4, bounce: 0.2).delay(0.2)) { sweep = 1 } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .garage: return "More than one car in the driveway?"
        case .history: return "Sell it with the paperwork."
        case .export: return "Take your numbers with you."
        default: return "What does this car really cost?"
        }
    }

    /// Three gauges swinging up to full: the dashboard warming up.
    var gauges: some View {
        HStack(spacing: 0) {
            gauge(0.62 * sweep, Dash.amber, "COSTS")
            gauge(0.85 * sweep, Dash.orange, "GARAGE")
            gauge(1.0 * sweep, Dash.ok, "PAPERS")
        }
        .frame(maxWidth: .infinity).tile()
    }

    func gauge(_ f: Double, _ c: Color, _ label: String) -> some View {
        VStack(spacing: 6) {
            DialGauge(fraction: f, color: c, size: 70, lineWidth: 8)
            Text(label).font(.ui(10, .black)).tracking(1.5).foregroundStyle(Dash.dim)
        }.frame(maxWidth: .infinity)
    }

    func feature(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 15, weight: .black)).foregroundStyle(Dash.amber)
                .frame(width: 36, height: 36).background(Circle().fill(Dash.card2)).overlay(Circle().strokeBorder(Dash.line2))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.ui(16, .heavy)).foregroundStyle(Dash.cream)
                Text(body).font(.ui(13, .medium)).foregroundStyle(Dash.grey).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var priceBlock: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pro.price).font(.num(36)).foregroundStyle(Dash.cream)
                Text("ONCE. NOT A MONTH.").font(.ui(11, .black)).tracking(1.8).foregroundStyle(Dash.amber)
            }
            Spacer()
            Text("Less than\nan oil change").font(.ui(12, .heavy)).multilineTextAlignment(.trailing).foregroundStyle(Dash.grey)
        }
        .tile()
    }
}

// MARK: - Locked pages

/// A Pro tab for a free user: the real page drawn from their own car, frosted, with a way in.
struct LockedPage<Content: View>: View {
    @Environment(Pro.self) private var pro
    let reason: Pro.Reason
    let title: String
    let pitch: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content.blur(radius: 10).allowsHitTesting(false).accessibilityHidden(true)
            LinearGradient(colors: [Dash.bg.opacity(0.2), Dash.bg.opacity(0.92)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Dash.card).frame(width: 100, height: 100).overlay(Circle().strokeBorder(Dash.amber.opacity(0.6), lineWidth: 2))
                    Image(systemName: "lock.fill").font(.system(size: 32, weight: .black)).foregroundStyle(Dash.amber)
                        .shadow(color: Dash.orange.opacity(0.7), radius: 14)
                }
                Plate(text: "PRO")
                Text(title).font(.big(28)).foregroundStyle(Dash.cream).multilineTextAlignment(.center)
                Text(pitch).font(.ui(15, .medium)).foregroundStyle(Dash.grey).multilineTextAlignment(.center).padding(.horizontal, 10)
                AmberButton(title: "See Odometer Pro", icon: "star.fill") { pro.ask(reason) }.padding(.horizontal, 30)
                Text("\(pro.price) once. One car stays free.").font(.ui(12, .bold)).foregroundStyle(Dash.dim)
            }
            .padding(.horizontal, 24).padding(.bottom, 100)
        }
    }
}

/// Pro status in Settings, with Restore always in reach.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(pro.unlocked ? Dash.amber : Dash.card2).frame(width: 40, height: 40)
                Image(systemName: pro.unlocked ? "checkmark" : "lock.fill").font(.system(size: 14, weight: .black)).foregroundStyle(pro.unlocked ? Dash.bg : Dash.grey)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(pro.unlocked ? "Odometer Pro" : "Odometer Pro, \(pro.price) once").font(.ui(16, .heavy)).foregroundStyle(Dash.cream)
                Text(pro.unlocked ? (pro.grandfathered ? "Unlocked. Thanks for being here early." : "Unlocked. Thank you.") : "More cars, costs, history PDF, CSV.")
                    .font(.ui(12, .medium)).foregroundStyle(Dash.grey)
                if let m = pro.message, pro.paywall == nil { Text(m).font(.ui(11.5, .semibold)).foregroundStyle(Dash.amber) }
            }
            Spacer(minLength: 6)
            if !pro.unlocked {
                VStack(alignment: .trailing, spacing: 8) {
                    Button { pro.ask(.settings) } label: {
                        Text("SEE").font(.ui(12, .black)).tracking(1.5).foregroundStyle(Dash.bg).padding(.horizontal, 14).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Dash.amber))
                    }.buttonStyle(.plain)
                    Button { Task { await pro.restore() } } label: {
                        Text("Restore").font(.ui(11, .bold)).foregroundStyle(Dash.dim).underline()
                    }.buttonStyle(.plain)
                }
            }
        }
        .tile(padding: 14)
    }
}
