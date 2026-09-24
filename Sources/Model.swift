import Foundation
import Observation

enum Day {
    static let cal: Calendar = { var c = Calendar(identifier: .iso8601); c.timeZone = .current; return c }()
    static let f: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.calendar = cal; f.timeZone = .current; return f }()
    static func key(_ d: Date) -> String { f.string(from: d) }
    static func date(_ k: String) -> Date { f.date(from: k) ?? .now }
    static var today: String { key(.now) }
    static func add(_ k: String, _ n: Int) -> String { key(cal.date(byAdding: .day, value: n, to: date(k))!) }
    static func addMonths(_ k: String, _ n: Int) -> String { key(cal.date(byAdding: .month, value: n, to: date(k))!) }
    static func diff(_ a: String, _ b: String) -> Int { cal.dateComponents([.day], from: date(a), to: date(b)).day ?? 0 }
    static func pretty(_ k: String) -> String { k.isEmpty ? "" : date(k).formatted(.dateTime.month(.abbreviated).day().year()) }
    static func short(_ k: String) -> String { k.isEmpty ? "" : date(k).formatted(.dateTime.month(.abbreviated).day()) }
    static func monthKey(_ k: String) -> String { String(k.prefix(7)) }
}

struct Interval: Codable, Hashable { var miles: Int; var months: Int }

struct Template: Identifiable, Hashable {
    let key: String; let name: String; let miles: Int; let months: Int; let icon: String
    var id: String { key }
    static let all: [Template] = [
        Template(key: "oil", name: "Oil and filter change", miles: 5000, months: 6, icon: "drop.fill"),
        Template(key: "tires", name: "Tire rotation", miles: 6000, months: 6, icon: "circle.dotted.circle"),
        Template(key: "cabin", name: "Cabin air filter", miles: 15000, months: 12, icon: "wind"),
        Template(key: "engine", name: "Engine air filter", miles: 15000, months: 12, icon: "aqi.medium"),
        Template(key: "wipers", name: "Wiper blades", miles: 0, months: 12, icon: "cloud.rain.fill"),
        Template(key: "brakefluid", name: "Brake fluid", miles: 30000, months: 24, icon: "exclamationmark.brakesignal"),
        Template(key: "coolant", name: "Coolant", miles: 60000, months: 60, icon: "thermometer.medium"),
        Template(key: "trans", name: "Transmission fluid", miles: 60000, months: 60, icon: "gearshape.2.fill"),
        Template(key: "plugs", name: "Spark plugs", miles: 60000, months: 72, icon: "bolt.fill"),
        Template(key: "battery", name: "Battery", miles: 0, months: 48, icon: "minus.plus.batteryblock.fill"),
        Template(key: "timing", name: "Timing belt", miles: 90000, months: 84, icon: "arrow.triangle.2.circlepath"),
    ]
    static func named(_ key: String) -> Template? { all.first { $0.key == key } }
}

struct Vehicle: Codable, Identifiable, Hashable {
    var id = UUID()
    var year: String = ""
    var make: String = ""
    var model: String = ""
    var nick: String = ""
    var plate: String = ""
    var vin: String = ""
    var bought: String = ""
    var boughtPrice: Double = 0
    var boughtMiles: Int = 0
    var insurance: String = ""
    var registration: String = ""
    var inspection: String = ""
    var warranty: String = ""
    var remind: Bool = false
    var overrides: [String: Interval] = [:]
    var custom: [CustomItem] = []
    var hidden: [String] = []
    var title: String { nick.isEmpty ? [year, make, model].filter { !$0.isEmpty }.joined(separator: " ") : nick }
    var longTitle: String { [year, make, model].filter { !$0.isEmpty }.joined(separator: " ") }
    var initials: String { String((make.isEmpty ? model : make).prefix(1)).uppercased() }
}

struct CustomItem: Codable, Identifiable, Hashable { var id = UUID(); var name: String; var miles: Int; var months: Int }

struct Reading: Codable, Identifiable, Hashable { var id = UUID(); var vehicle: UUID; var date: String; var miles: Int }

struct Service: Codable, Identifiable, Hashable {
    var id = UUID(); var vehicle: UUID; var date: String; var miles: Int
    var type: String            // template key, custom item id string, or free text
    var diy: Bool = false; var shop: String = ""; var parts: Double = 0; var labor: Double = 0; var note: String = ""
    var cost: Double { parts + labor }
}

struct Fuel: Codable, Identifiable, Hashable {
    var id = UUID(); var vehicle: UUID; var date: String; var miles: Int
    var gallons: Double; var price: Double; var full: Bool = true
}

enum ExpenseKind: String, Codable, CaseIterable {
    case insurance = "Insurance", registration = "Registration", parking = "Parking", tolls = "Tolls", wash = "Car wash", other = "Other"
}

struct Expense: Codable, Identifiable, Hashable { var id = UUID(); var vehicle: UUID; var date: String; var kind: ExpenseKind; var amount: Double; var note: String = "" }

struct Settings: Codable { var metric = false; var litres = false; var currency = "$" }

enum DueStatus { case ok, soon, overdue
    var label: String { switch self { case .ok: return "OK"; case .soon: return "DUE SOON"; case .overdue: return "OVERDUE" } }
}

struct DueItem: Identifiable {
    var id: String
    var name: String
    var icon: String
    var interval: Interval
    var last: Service?
    var lastMiles: Int
    var lastDate: String
    var dueMiles: Int?
    var dueDate: String?
    var status: DueStatus
    var fraction: Double
    var predicted: String?      // predicted date the miles run out, from pace
    var milesLeft: Int?
    var daysLeft: Int?
}

struct Paper: Identifiable { var id: String; var name: String; var date: String; var days: Int }

@Observable
final class Store {
    var vehicles: [Vehicle] = []
    var readings: [Reading] = []
    var services: [Service] = []
    var fuel: [Fuel] = []
    var expenses: [Expense] = []
    var settings = Settings()
    var current: UUID? = nil
    private var saveTask: Task<Void, Never>?
    private let url = URL.documentsDirectory.appending(path: "odometer.json")
    struct Disk: Codable { var vehicles: [Vehicle]; var readings: [Reading]; var services: [Service]; var fuel: [Fuel]; var expenses: [Expense]; var settings: Settings; var current: UUID? }

    init(demo: Bool) {
        if demo { Demo.fill(self); return }
        if let d = try? Data(contentsOf: url), let disk = try? JSONDecoder().decode(Disk.self, from: d) {
            vehicles = disk.vehicles; readings = disk.readings; services = disk.services; fuel = disk.fuel; expenses = disk.expenses; settings = disk.settings; current = disk.current
        }
        if current == nil { current = vehicles.first?.id }
    }
    func save() {
        saveTask?.cancel(); let disk = Disk(vehicles: vehicles, readings: readings, services: services, fuel: fuel, expenses: expenses, settings: settings, current: current); let u = url
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(200)); if Task.isCancelled { return }
            if let d = try? JSONEncoder().encode(disk) { try? d.write(to: u, options: .atomic) }
        }
    }

    var car: Vehicle? { vehicles.first { $0.id == current } ?? vehicles.first }
    func upsert(_ v: Vehicle) { if let i = vehicles.firstIndex(where: { $0.id == v.id }) { vehicles[i] = v } else { vehicles.append(v); current = v.id }; save(); Reminders.sync(self) }
    func delete(_ v: Vehicle) {
        vehicles.removeAll { $0.id == v.id }; readings.removeAll { $0.vehicle == v.id }; services.removeAll { $0.vehicle == v.id }; fuel.removeAll { $0.vehicle == v.id }; expenses.removeAll { $0.vehicle == v.id }
        if current == v.id { current = vehicles.first?.id }; save()
    }

    // MARK: Miles and pace
    func miles(_ v: Vehicle) -> Int {
        let a = readings.filter { $0.vehicle == v.id }.map { $0.miles } + services.filter { $0.vehicle == v.id }.map { $0.miles } + fuel.filter { $0.vehicle == v.id }.map { $0.miles }
        return max(a.max() ?? 0, v.boughtMiles)
    }
    func setMiles(_ v: Vehicle, _ m: Int) { readings.append(Reading(vehicle: v.id, date: Day.today, miles: m)); save() }
    /// Miles per day from every dated mileage point in the last 180 days.
    func pace(_ v: Vehicle) -> Double {
        var pts: [(String, Int)] = readings.filter { $0.vehicle == v.id }.map { ($0.date, $0.miles) } + services.filter { $0.vehicle == v.id }.map { ($0.date, $0.miles) } + fuel.filter { $0.vehicle == v.id }.map { ($0.date, $0.miles) }
        if !v.bought.isEmpty && v.boughtMiles > 0 { pts.append((v.bought, v.boughtMiles)) }
        pts = pts.filter { $0.1 > 0 }.sorted { $0.0 < $1.0 }
        let cutoff = Day.add(Day.today, -180)
        let recent = pts.filter { $0.0 >= cutoff }
        let use = recent.count >= 2 ? recent : pts
        guard let a = use.first, let b = use.last, b.1 > a.1 else { return 0 }
        let d = max(1, Day.diff(a.0, b.0)); return Double(b.1 - a.1) / Double(d)
    }

    // MARK: Schedule
    func typeName(_ v: Vehicle, _ key: String) -> String {
        if let t = Template.named(key) { return t.name }
        if let c = v.custom.first(where: { $0.id.uuidString == key }) { return c.name }
        return key
    }
    func typeIcon(_ v: Vehicle, _ key: String) -> String { Template.named(key)?.icon ?? (v.custom.contains { $0.id.uuidString == key } ? "wrench.adjustable.fill" : "wrench.fill") }
    func interval(_ v: Vehicle, _ key: String) -> Interval {
        if let o = v.overrides[key] { return o }
        if let t = Template.named(key) { return Interval(miles: t.miles, months: t.months) }
        if let c = v.custom.first(where: { $0.id.uuidString == key }) { return Interval(miles: c.miles, months: c.months) }
        return Interval(miles: 0, months: 0)
    }
    func schedule(_ v: Vehicle) -> [DueItem] {
        let now = miles(v), p = pace(v), today = Day.today
        var keys = Template.all.map { $0.key }.filter { !v.hidden.contains($0) }
        keys += v.custom.map { $0.id.uuidString }
        var out: [DueItem] = []
        for k in keys {
            let iv = interval(v, k)
            let last = services.filter { $0.vehicle == v.id && $0.type == k }.max { ($0.date, $0.miles) < ($1.date, $1.miles) }
            let lm = last?.miles ?? v.boughtMiles, ld = last?.date ?? (v.bought.isEmpty ? Day.add(today, -365) : v.bought)
            let dm: Int? = iv.miles > 0 ? lm + iv.miles : nil
            let dd: String? = iv.months > 0 ? Day.addMonths(ld, iv.months) : nil
            let mLeft = dm.map { $0 - now }, dLeft = dd.map { Day.diff(today, $0) }
            var st = DueStatus.ok
            if (mLeft ?? 1) <= 0 || (dLeft ?? 1) <= 0 { st = .overdue } else if (mLeft ?? 99999) <= 500 || (dLeft ?? 999) <= 30 { st = .soon }
            let fm = iv.miles > 0 ? Double(now - lm) / Double(iv.miles) : 0
            let fd = iv.months > 0 ? Double(Day.diff(ld, today)) / Double(iv.months * 30) : 0
            var pred: String? = nil
            if let mLeft, mLeft > 0, p > 0 { pred = Day.add(today, Int(Double(mLeft) / p)) }
            out.append(DueItem(id: k, name: typeName(v, k), icon: typeIcon(v, k), interval: iv, last: last, lastMiles: lm, lastDate: ld, dueMiles: dm, dueDate: dd, status: st, fraction: max(fm, fd), predicted: pred, milesLeft: mLeft, daysLeft: dLeft))
        }
        let rank: (DueStatus) -> Int = { $0 == .overdue ? 0 : $0 == .soon ? 1 : 2 }
        return out.sorted { (rank($0.status), -$0.fraction) < (rank($1.status), -$1.fraction) }
    }
    func papers(_ v: Vehicle) -> [Paper] {
        [("Insurance renewal", v.insurance), ("Registration", v.registration), ("Inspection", v.inspection), ("Warranty ends", v.warranty)]
            .filter { !$0.1.isEmpty }.map { Paper(id: $0.0, name: $0.0, date: $0.1, days: Day.diff(Day.today, $0.1)) }.sorted { $0.days < $1.days }
    }

    // MARK: Fuel
    func fuelFor(_ v: Vehicle) -> [Fuel] { fuel.filter { $0.vehicle == v.id }.sorted { ($0.date, $0.miles) < ($1.date, $1.miles) } }
    struct Economy: Identifiable { var id: UUID; var date: String; var miles: Int; var mpg: Double; var costPerMile: Double }
    /// Economy between consecutive full tanks.
    func economy(_ v: Vehicle) -> [Economy] {
        let f = fuelFor(v); var out: [Economy] = []
        var i = 0
        while i < f.count {
            guard f[i].full else { i += 1; continue }
            var j = i + 1, gal = 0.0, cost = 0.0
            while j < f.count { gal += f[j].gallons; cost += f[j].price; if f[j].full { break }; j += 1 }
            if j < f.count, f[j].miles > f[i].miles, gal > 0 {
                let d = Double(f[j].miles - f[i].miles)
                out.append(Economy(id: f[j].id, date: f[j].date, miles: f[j].miles, mpg: d / gal, costPerMile: cost / d))
            }
            i = j
        }
        return out
    }
    func avgMpg(_ v: Vehicle) -> Double { let e = economy(v); return e.isEmpty ? 0 : e.map { $0.mpg }.reduce(0, +) / Double(e.count) }

    // MARK: Costs
    struct Slice: Identifiable { var id: String { name }; var name: String; var amount: Double }
    func costItems(_ v: Vehicle, since: String) -> [(String, String, Double)] {
        var out: [(String, String, Double)] = []
        for s in services where s.vehicle == v.id && s.date >= since { out.append((s.date, "Service", s.cost)) }
        for f in fuel where f.vehicle == v.id && f.date >= since { out.append((f.date, "Fuel", f.price)) }
        for e in expenses where e.vehicle == v.id && e.date >= since { out.append((e.date, e.kind.rawValue, e.amount)) }
        return out
    }
    func slices(_ v: Vehicle, since: String) -> [Slice] {
        var d: [String: Double] = [:]
        for (_, k, a) in costItems(v, since: since) { d[k, default: 0] += a }
        return d.map { Slice(name: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }
    struct MonthBar: Identifiable { var id: String { month }; var month: String; var label: String; var amount: Double }
    func monthBars(_ v: Vehicle) -> [MonthBar] {
        let items = costItems(v, since: Day.add(Day.today, -365))
        return (0..<12).reversed().map { i in
            let m = Day.monthKey(Day.addMonths(Day.today, -i))
            let a = items.filter { Day.monthKey($0.0) == m }.map { $0.2 }.reduce(0, +)
            return MonthBar(month: m, label: String(Day.date(m + "-01").formatted(.dateTime.month(.narrow))), amount: a)
        }
    }
    func ownershipMonths(_ v: Vehicle) -> Int {
        let firstDates = ([v.bought] + costItems(v, since: "0000").map { $0.0 }).filter { !$0.isEmpty }.min() ?? Day.today
        return max(1, Int((Double(Day.diff(firstDates, Day.today)) / 30.4).rounded(.up)))
    }
    func totalCost(_ v: Vehicle) -> Double { costItems(v, since: "0000").map { $0.2 }.reduce(0, +) }
    func milesDriven(_ v: Vehicle) -> Int { max(0, miles(v) - v.boughtMiles) }

    // MARK: Units
    func dist(_ mi: Int) -> String { settings.metric ? "\(Int((Double(mi) * 1.609344).rounded()).formatted()) km" : "\(mi.formatted()) mi" }
    func distShort(_ mi: Int) -> String { settings.metric ? "\(Int((Double(mi) * 1.609344).rounded()).formatted())" : mi.formatted() }
    var distUnit: String { settings.metric ? "km" : "mi" }
    var volUnit: String { settings.litres ? "L" : "gal" }
    func vol(_ g: Double) -> String { settings.litres ? String(format: "%.1f L", g * 3.78541) : String(format: "%.2f gal", g) }
    func econ(_ mpg: Double) -> String {
        guard mpg > 0 else { return "–" }
        if settings.metric && settings.litres { return String(format: "%.1f", 235.215 / mpg) }
        if settings.metric { return String(format: "%.1f", mpg * 0.4251) }
        return String(format: "%.1f", mpg)
    }
    var econUnit: String { settings.metric && settings.litres ? "L/100km" : settings.metric ? "km/L" : "mpg" }
    func money(_ x: Double) -> String { let s = settings.currency; return x < 0 ? "-\(s)\(abs(x).formatted(.number.precision(.fractionLength(0))))" : "\(s)\(x.formatted(.number.precision(.fractionLength(x < 100 && x != x.rounded() ? 2 : 0))))" }
    func money2(_ x: Double) -> String { "\(settings.currency)\(x.formatted(.number.precision(.fractionLength(2))))" }
    /// Miles in, display units out (for entry fields).
    func toDisplay(_ mi: Int) -> Int { settings.metric ? Int((Double(mi) * 1.609344).rounded()) : mi }
    func fromDisplay(_ d: Int) -> Int { settings.metric ? Int((Double(d) / 1.609344).rounded()) : d }
    func galFromDisplay(_ x: Double) -> Double { settings.litres ? x / 3.78541 : x }
    func galToDisplay(_ g: Double) -> Double { settings.litres ? g * 3.78541 : g }

    // MARK: CSV
    func csv(_ v: Vehicle) -> String {
        var rows: [String] = []
        for s in services where s.vehicle == v.id { rows.append("service,\(s.date),\(toDisplay(s.miles)),\"\(typeName(v, s.type))\",\"\(s.diy ? "DIY" : s.shop) \(s.note)\",\(String(format: "%.2f", s.cost))") }
        for f in fuel where f.vehicle == v.id { rows.append("fuel,\(f.date),\(toDisplay(f.miles)),fill-up,\"\(vol(f.gallons))\(f.full ? " full" : " partial")\",\(String(format: "%.2f", f.price))") }
        for e in expenses where e.vehicle == v.id { rows.append("expense,\(e.date),,\(e.kind.rawValue),\"\(e.note)\",\(String(format: "%.2f", e.amount))") }
        for r in readings where r.vehicle == v.id { rows.append("reading,\(r.date),\(toDisplay(r.miles)),odometer,,") }
        let sorted = rows.sorted { String($0.split(separator: ",", maxSplits: 2)[1]) < String($1.split(separator: ",", maxSplits: 2)[1]) }
        return (["type,date,\(distUnit),item,detail,cost"] + sorted).joined(separator: "\n")
    }
}

