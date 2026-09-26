import SwiftUI
import Charts
import UIKit

// MARK: Garage strip

struct GarageStrip: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.vehicles) { v in
                    let on = v.id == store.car?.id
                    let bad = store.schedule(v).contains { $0.status == .overdue } || store.papers(v).contains { $0.days < 0 }
                    Button { withAnimation(.snappy(duration: 0.25)) { store.current = v.id; store.save() } } label: {
                        HStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                Plate(text: v.plate.isEmpty ? v.initials : v.plate, small: true)
                                if bad { Circle().fill(Dash.red).frame(width: 8, height: 8).offset(x: 3, y: -3) }
                            }
                            Text(v.title).font(.ui(13, .heavy)).foregroundStyle(on ? Dash.cream : Dash.grey).lineLimit(1)
                        }
                        .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Dash.card2 : Dash.card))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? Dash.amber.opacity(0.7) : Dash.line))
                    }.buttonStyle(.plain)
                }
                Button {
                    // The first vehicle is free; the garage is Pro.
                    if pro.unlocked || store.vehicles.isEmpty { router.sheet = .vehicle(Vehicle()) } else { pro.ask(.garage) }
                } label: {
                    Image(systemName: pro.unlocked || store.vehicles.isEmpty ? "plus" : "lock.fill").font(.system(size: 14, weight: .black)).foregroundStyle(Dash.grey).frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Dash.card)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Dash.line2))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 16)
        }.padding(.horizontal, -16)
    }
}

struct EmptyGarage: View {
    @Environment(Router.self) private var router
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            OdoRoller(value: 0, size: 38)
            Text("Empty garage.").font(.big(30)).foregroundStyle(Dash.cream)
            Text("Add a car, type its mileage, and Odometer starts counting down to the next oil change.").font(.ui(14, .medium)).foregroundStyle(Dash.grey).multilineTextAlignment(.center).padding(.horizontal, 30)
            AmberButton(title: "Add a vehicle", icon: "plus") { router.sheet = .vehicle(Vehicle()) }.padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: Car

struct CarView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        if let v = store.car {
            let sched = store.schedule(v), overdue = sched.filter { $0.status == .overdue }, soon = sched.filter { $0.status == .soon }
            let papers = store.papers(v), pace = store.pace(v), mpg = store.avgMpg(v)
            let months = store.ownershipMonths(v), total = store.totalCost(v), driven = store.milesDriven(v)
            Page {
                GarageStrip().padding(.top, 10)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(v.title).font(.big(28)).foregroundStyle(Dash.cream).lineLimit(2).minimumScaleFactor(0.7)
                        if !v.nick.isEmpty { Text(v.longTitle).font(.ui(13, .medium)).foregroundStyle(Dash.grey) }
                        HStack(spacing: 8) {
                            Plate(text: v.plate)
                            if !v.vin.isEmpty { Text("VIN " + v.vin.suffix(6)).font(.mono(11)).foregroundStyle(Dash.dim) }
                        }.padding(.top, 4)
                    }
                    Spacer()
                    Button { router.sheet = .vehicle(v) } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .bold)).foregroundStyle(Dash.grey).frame(width: 38, height: 38).background(Circle().fill(Dash.card)) }.buttonStyle(.plain)
                    Button { router.sheet = .settings } label: { Image(systemName: "gearshape.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Dash.grey).frame(width: 38, height: 38).background(Circle().fill(Dash.card)) }.buttonStyle(.plain)
                }
                // Odometer
                Button { router.sheet = .reading } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Eyebrow("Odometer"); Spacer(); Text("tap to update").font(.ui(11, .heavy)).foregroundStyle(Dash.amber) }
                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            OdoRoller(value: store.toDisplay(store.miles(v)), size: 34)
                            Text(store.distUnit).font(.ui(14, .heavy)).foregroundStyle(Dash.grey)
                        }
                        Text(pace > 0 ? "About \(store.distShort(Int(pace * 30.4))) \(store.distUnit) a month at your pace" : "Log a fill-up or a reading to learn your pace").font(.ui(12, .medium)).foregroundStyle(Dash.dim)
                    }.frame(maxWidth: .infinity, alignment: .leading).tile()
                }.buttonStyle(.plain)
                // Status tiles
                HStack(spacing: 10) {
                    let n = overdue.count + soon.count
                    Stat(label: "Maintenance", value: overdue.isEmpty ? (soon.isEmpty ? "All good" : "\(soon.count) soon") : "\(overdue.count) overdue", sub: n > 0 ? (overdue.first ?? soon.first)!.name : "Nothing due", color: overdue.isEmpty ? (soon.isEmpty ? Dash.ok : Dash.amber) : Dash.red)
                    Stat(label: "Per month", value: store.money(total / Double(months)), sub: "\(store.money(total)) over \(months) months")
                }
                HStack(spacing: 10) {
                    Stat(label: "Per \(store.distUnit)", value: driven > 0 ? store.money2(total / Double(store.toDisplay(driven))) : "–", sub: "\(store.dist(driven)) since you got it")
                    Stat(label: "Economy", value: store.econ(mpg), sub: mpg > 0 ? "\(store.econUnit), full tanks average" : "needs two full tanks")
                }
                // Needs doing
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("What needs doing").font(.ui(17, .heavy)).foregroundStyle(Dash.cream); Spacer(); GreyButton(title: "Full schedule") { router.tab = .due } }
                    ForEach(Array((overdue + soon).prefix(4))) { d in DueRow(item: d, compact: true) }
                    if overdue.isEmpty && soon.isEmpty {
                        HStack(spacing: 10) { Image(systemName: "checkmark.seal.fill").foregroundStyle(Dash.ok); Text("Nothing due in the next 500 \(store.distUnit) or 30 days.").font(.ui(13, .medium)).foregroundStyle(Dash.grey) }
                    }
                }.tile()
                // Paperwork
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("Glovebox").font(.ui(17, .heavy)).foregroundStyle(Dash.cream); Spacer(); if v.remind { HStack(spacing: 4) { Image(systemName: "bell.fill"); Text("reminders on") }.font(.ui(11, .heavy)).foregroundStyle(Dash.amber) } }
                    if papers.isEmpty { Text("Add insurance, registration and inspection dates in the car's settings.").font(.ui(13, .medium)).foregroundStyle(Dash.grey) }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(papers) { p in PaperCard(paper: p) }
                    }
                }.tile()
                HStack(spacing: 10) {
                    GreyButton(title: "Service history", icon: pro.unlocked ? "doc.text.fill" : "lock.fill") { if pro.unlocked { router.sheet = .history } else { pro.ask(.history) } }
                    GreyButton(title: "Log a service", icon: "wrench.fill") { router.sheet = .service(nil) }
                }
            }
        }
    }
}

struct PaperCard: View {
    let paper: Paper
    var body: some View {
        let c: Color = paper.days < 0 ? Dash.red : paper.days <= 30 ? Dash.amber : Dash.ok
        VStack(alignment: .leading, spacing: 4) {
            Text(paper.name).font(.ui(12, .heavy)).foregroundStyle(Dash.cream).lineLimit(1)
            Text(paper.days < 0 ? "\(-paper.days) days ago" : paper.days == 0 ? "today" : "in \(paper.days) days").font(.num(16)).foregroundStyle(c)
            Text(Day.pretty(paper.date)).font(.ui(11, .medium)).foregroundStyle(Dash.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Dash.bg2)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(c.opacity(0.35)))
    }
}

// MARK: Due

struct DueView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        if let v = store.car {
            let sched = store.schedule(v)
            Page {
                GarageStrip().padding(.top, 10)
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Due.").font(.big(30)).foregroundStyle(Dash.cream)
                        Text("Counted from the last time each job was done. Dates are predicted from how far you drive.").font(.ui(13, .medium)).foregroundStyle(Dash.grey)
                    }
                    Spacer()
                    Button { router.sheet = .intervals } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .bold)).foregroundStyle(Dash.grey).frame(width: 38, height: 38).background(Circle().fill(Dash.card)) }.buttonStyle(.plain)
                }
                ForEach(sched) { d in DueRow(item: d, compact: false) }
                AmberButton(title: "Log a service", icon: "wrench.fill") { router.sheet = .service(nil) }
            }
        }
    }
}

struct DueRow: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let item: DueItem
    let compact: Bool
    var body: some View {
        let v = store.car!
        Button { router.sheet = .service(Service(vehicle: v.id, date: Day.today, miles: store.miles(v), type: item.id)) } label: {
            HStack(spacing: 12) {
                DialGauge(fraction: item.fraction, color: item.status.color, size: compact ? 46 : 54, lineWidth: compact ? 6 : 7)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) { Image(systemName: item.icon).font(.system(size: 12, weight: .bold)).foregroundStyle(item.status.color); Text(item.name).font(.ui(15, .heavy)).foregroundStyle(Dash.cream).lineLimit(1) }
                    Text(line1).font(.ui(11.5, .medium)).foregroundStyle(Dash.grey).lineLimit(2)
                    if !compact { Text(line2).font(.ui(11.5, .medium)).foregroundStyle(Dash.dim).lineLimit(2) }
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 4) {
                    StatusPill(status: item.status)
                    Text(when).font(.ui(11, .heavy)).foregroundStyle(item.status.color).multilineTextAlignment(.trailing)
                }
            }
            .padding(compact ? 10 : 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(item.status == .overdue ? Dash.red.opacity(0.08) : Dash.bg2))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(item.status == .overdue ? Dash.red.opacity(0.4) : Dash.line))
        }.buttonStyle(.plain)
    }
    var line1: String {
        if item.last == nil { return "Never logged. Counting from \(Day.short(item.lastDate)) at \(store.dist(item.lastMiles))." }
        return "Last done \(Day.pretty(item.lastDate)) at \(store.dist(item.lastMiles))"
    }
    var line2: String {
        var p: [String] = []
        if item.interval.miles > 0 { p.append("every \(store.dist(item.interval.miles))") }
        if item.interval.months > 0 { p.append("every \(item.interval.months) months") }
        if let pr = item.predicted, (item.milesLeft ?? 0) > 0 { p.append("about \(Day.short(pr)) at your pace") }
        return p.joined(separator: " · ")
    }
    var when: String {
        switch item.status {
        case .overdue:
            if let m = item.milesLeft, m <= 0 { return "\(store.distShort(-m)) \(store.distUnit) over" }
            if let d = item.daysLeft, d <= 0 { return "\(-d) days over" }
            return ""
        default:
            var a: [String] = []
            if let m = item.milesLeft { a.append("in \(store.distShort(m)) \(store.distUnit)") }
            if let d = item.daysLeft { a.append(d < 60 ? "\(d) days" : Day.short(item.dueDate ?? "")) }
            return a.joined(separator: "\n")
        }
    }
}

// MARK: Fuel

struct FuelView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        if let v = store.car {
            let fills = store.fuelFor(v).reversed(), econ = store.economy(v), avg = store.avgMpg(v)
            let recent = Array(econ.suffix(24))
            let spend = fills.filter { $0.date >= Day.add(Day.today, -365) }.map { $0.price }.reduce(0, +)
            let cpm = econ.isEmpty ? 0 : econ.suffix(10).map { $0.costPerMile }.reduce(0, +) / Double(min(10, econ.count))
            Page {
                GarageStrip().padding(.top, 10)
                HStack(alignment: .lastTextBaseline) {
                    Text("Fuel.").font(.big(30)).foregroundStyle(Dash.cream)
                    Spacer()
                    Text("\(fills.count) fill-ups").font(.ui(13, .heavy)).foregroundStyle(Dash.grey)
                }
                HStack(spacing: 10) {
                    Stat(label: store.econUnit, value: store.econ(avg), sub: "average, full tank to full tank", color: Dash.amber)
                    Stat(label: "Per \(store.distUnit)", value: cpm > 0 ? store.money2(cpm / (store.settings.metric ? 1.609344 : 1)) : "–", sub: "last ten tanks")
                    Stat(label: "This year", value: store.money(spend), sub: "spent on fuel")
                }
                if recent.count >= 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Economy per tank")
                        Chart(recent) { e in
                            AreaMark(x: .value("Date", Day.date(e.date)), y: .value("mpg", econValue(e.mpg))).foregroundStyle(LinearGradient(colors: [Dash.amber.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)).interpolationMethod(.catmullRom)
                            LineMark(x: .value("Date", Day.date(e.date)), y: .value("mpg", econValue(e.mpg))).foregroundStyle(Dash.amber).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", Day.date(e.date)), y: .value("mpg", econValue(e.mpg))).foregroundStyle(Dash.cream).symbolSize(18)
                            RuleMark(y: .value("avg", econValue(avg))).foregroundStyle(Dash.dim).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine().foregroundStyle(Dash.line); AxisValueLabel().foregroundStyle(Dash.dim).font(.ui(10, .bold)) } }
                        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in AxisGridLine().foregroundStyle(Dash.line); AxisValueLabel().foregroundStyle(Dash.dim).font(.ui(10, .bold)) } }
                        .frame(height: 170)
                    }.tile()
                }
                AmberButton(title: "Add a fill-up", icon: "fuelpump.fill") { router.sheet = .fuel(nil) }
                VStack(spacing: 0) {
                    ForEach(Array(fills.prefix(40))) { f in
                        let e = econ.first { $0.id == f.id }
                        Button { router.sheet = .fuel(f) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Day.pretty(f.date)).font(.ui(14, .heavy)).foregroundStyle(Dash.cream)
                                    Text("\(store.dist(f.miles)) · \(store.vol(f.gallons))\(f.full ? "" : " · partial")").font(.ui(11.5, .medium)).foregroundStyle(Dash.dim)
                                }
                                Spacer()
                                if let e { Text(store.econ(e.mpg)).font(.num(15)).foregroundStyle(e.mpg >= avg ? Dash.ok : Dash.amber) + Text(" \(store.econUnit)").font(.ui(10, .heavy)).foregroundStyle(Dash.dim) }
                                Text(store.money2(f.price)).font(.num(15)).foregroundStyle(Dash.cream).frame(width: 74, alignment: .trailing)
                            }.padding(.vertical, 10)
                        }.buttonStyle(.plain)
                        Divider().overlay(Dash.line)
                    }
                    if fills.isEmpty { Text("No fill-ups yet. Two full tanks in a row give you the first economy figure.").font(.ui(13, .medium)).foregroundStyle(Dash.grey).padding(.vertical, 8) }
                }.tile(padding: 14)
            }
        }
    }
    func econValue(_ mpg: Double) -> Double { Double(store.econ(mpg)) ?? 0 }
}

// MARK: Log

struct LogView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var mode = 0
    var body: some View {
        if let v = store.car {
            let svcs = store.services.filter { $0.vehicle == v.id }.sorted { ($0.date, $0.miles) > ($1.date, $1.miles) }
            let exps = store.expenses.filter { $0.vehicle == v.id }.sorted { $0.date > $1.date }
            Page {
                GarageStrip().padding(.top, 10)
                HStack(alignment: .lastTextBaseline) {
                    Text("Log.").font(.big(30)).foregroundStyle(Dash.cream)
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(["Services", "Expenses"].indices, id: \.self) { i in
                            Button { withAnimation(.snappy(duration: 0.2)) { mode = i } } label: {
                                Text(["Services", "Expenses"][i]).font(.ui(12, .heavy)).foregroundStyle(mode == i ? Dash.bg : Dash.grey).padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Group { if mode == i { Capsule().fill(Dash.amber) } })
                            }.buttonStyle(.plain)
                        }
                    }.padding(3).background(Capsule().fill(Dash.card)).overlay(Capsule().strokeBorder(Dash.line2))
                }
                if mode == 0 {
                    AmberButton(title: "Log a service", icon: "wrench.fill") { router.sheet = .service(nil) }
                    let groups = Dictionary(grouping: svcs) { String($0.date.prefix(4)) }
                    ForEach(groups.keys.sorted(by: >), id: \.self) { y in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack { Eyebrow(y); Spacer(); Text(store.money(groups[y]!.map { $0.cost }.reduce(0, +))).font(.num(13)).foregroundStyle(Dash.grey) }.padding(.bottom, 6)
                            ForEach(groups[y]!) { s in
                                Button { router.sheet = .service(s) } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: store.typeIcon(v, s.type)).font(.system(size: 14, weight: .bold)).foregroundStyle(Dash.amber).frame(width: 34, height: 34).background(Circle().fill(Dash.card2))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(store.typeName(v, s.type)).font(.ui(14, .heavy)).foregroundStyle(Dash.cream)
                                            Text("\(Day.pretty(s.date)) · \(store.dist(s.miles)) · \(s.diy ? "DIY" : s.shop.isEmpty ? "shop" : s.shop)").font(.ui(11.5, .medium)).foregroundStyle(Dash.dim)
                                            if !s.note.isEmpty { Text(s.note).font(.ui(11.5, .medium)).foregroundStyle(Dash.grey).lineLimit(2) }
                                        }
                                        Spacer()
                                        Text(store.money(s.cost)).font(.num(15)).foregroundStyle(Dash.cream)
                                    }.padding(.vertical, 9)
                                }.buttonStyle(.plain)
                                Divider().overlay(Dash.line)
                            }
                        }.tile(padding: 14)
                    }
                    if svcs.isEmpty { Text("No services logged. Tap a job on the Due tab or the button above.").font(.ui(13, .medium)).foregroundStyle(Dash.grey).tile() }
                } else {
                    AmberButton(title: "Add an expense", icon: "creditcard.fill") { router.sheet = .expense(nil) }
                    VStack(spacing: 0) {
                        ForEach(exps.prefix(60)) { e in
                            Button { router.sheet = .expense(e) } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.kind.rawValue).font(.ui(14, .heavy)).foregroundStyle(Dash.cream)
                                        Text(Day.pretty(e.date) + (e.note.isEmpty ? "" : " · " + e.note)).font(.ui(11.5, .medium)).foregroundStyle(Dash.dim).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(store.money(e.amount)).font(.num(15)).foregroundStyle(Dash.cream)
                                }.padding(.vertical, 9)
                            }.buttonStyle(.plain)
                            Divider().overlay(Dash.line)
                        }
                        if exps.isEmpty { Text("Insurance, registration, parking, tolls, washes. They all count in the cost per \(store.distUnit).").font(.ui(13, .medium)).foregroundStyle(Dash.grey).padding(.vertical, 8) }
                    }.tile(padding: 14)
                }
            }
        }
    }
}

// MARK: Costs

struct CostsView: View {
    @Environment(Store.self) private var store
    var body: some View {
        if let v = store.car {
            let since = Day.add(Day.today, -365)
            let year = store.costItems(v, since: since).map { $0.2 }.reduce(0, +)
            let slices = store.slices(v, since: since), bars = store.monthBars(v)
            let total = store.totalCost(v), months = store.ownershipMonths(v), driven = store.milesDriven(v)
            let yearMiles = yearDriven(v)
            Page {
                GarageStrip().padding(.top, 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Costs.").font(.big(30)).foregroundStyle(Dash.cream)
                    Text("Fuel, services and paperwork together. Purchase price is kept separate.").font(.ui(13, .medium)).foregroundStyle(Dash.grey)
                }
                HStack(spacing: 10) {
                    Stat(label: "Last 12 months", value: store.money(year), sub: "\(store.money(year / 12)) a month", color: Dash.amber)
                    Stat(label: "Per \(store.distUnit)", value: yearMiles > 0 ? store.money2(year / Double(store.toDisplay(yearMiles))) : "–", sub: "\(store.dist(yearMiles)) this year")
                }
                HStack(spacing: 10) {
                    Stat(label: "Since you got it", value: store.money(total), sub: "\(months) months, \(store.dist(driven))")
                    Stat(label: "Bought for", value: v.boughtPrice > 0 ? store.money(v.boughtPrice) : "–", sub: v.bought.isEmpty ? "" : Day.pretty(v.bought))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("By month")
                    Chart(bars) { b in
                        BarMark(x: .value("Month", b.label + b.month), y: .value("Amount", b.amount)).foregroundStyle(LinearGradient(colors: [Dash.amber, Dash.orange], startPoint: .top, endPoint: .bottom)).cornerRadius(5)
                    }
                    .chartXAxis { AxisMarks { val in AxisValueLabel { if let s = val.as(String.self) { Text(String(s.prefix(1))).font(.ui(10, .bold)).foregroundStyle(Dash.dim) } } } }
                    .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in AxisGridLine().foregroundStyle(Dash.line); AxisValueLabel().foregroundStyle(Dash.dim).font(.ui(10, .bold)) } }
                    .frame(height: 150)
                }.tile()
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Where the money goes")
                    let mx = slices.first?.amount ?? 1
                    ForEach(slices) { s in
                        HStack(spacing: 10) {
                            Text(s.name).font(.ui(13, .heavy)).foregroundStyle(Dash.cream).frame(width: 96, alignment: .leading)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Dash.line)
                                    Capsule().fill(color(for: s.name)).frame(width: max(6, g.size.width * CGFloat(s.amount / mx)))
                                }
                            }.frame(height: 10)
                            Text(store.money(s.amount)).font(.num(13)).foregroundStyle(Dash.grey).frame(width: 66, alignment: .trailing)
                            Text(year > 0 ? "\(Int((s.amount / year * 100).rounded()))%" : "").font(.ui(11, .heavy)).foregroundStyle(Dash.dim).frame(width: 34, alignment: .trailing)
                        }
                    }
                    if slices.isEmpty { Text("Nothing in the last twelve months.").font(.ui(13, .medium)).foregroundStyle(Dash.grey) }
                }.tile()
            }
        }
    }
    func yearDriven(_ v: Vehicle) -> Int {
        let since = Day.add(Day.today, -365)
        let pts = (store.readings.filter { $0.vehicle == v.id }.map { ($0.date, $0.miles) } + store.fuel.filter { $0.vehicle == v.id }.map { ($0.date, $0.miles) } + store.services.filter { $0.vehicle == v.id }.map { ($0.date, $0.miles) }).filter { $0.0 >= since }.map { $0.1 }
        guard let lo = pts.min(), let hi = pts.max() else { return 0 }
        return hi - lo
    }
    func color(for name: String) -> Color {
        switch name { case "Fuel": return Dash.amber; case "Service": return Dash.orange; case "Insurance": return Dash.blue; case "Registration": return Dash.ok; default: return Dash.grey }
    }
}

// MARK: Editors

struct VehicleEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var vehicle: Vehicle
    @State private var milesText = ""
    var isNew: Bool { !store.vehicles.contains { $0.id == vehicle.id } }
    var body: some View {
        SheetPage(title: isNew ? "New vehicle" : "Edit vehicle") {
            HStack(spacing: 10) {
                Field(label: "Year") { TextField("2019", text: $vehicle.year).keyboardType(.numberPad) }.frame(width: 90)
                Field(label: "Make") { TextField("Toyota", text: $vehicle.make) }
                Field(label: "Model") { TextField("RAV4", text: $vehicle.model) }
            }
            HStack(spacing: 10) {
                Field(label: "Nickname") { TextField("optional", text: $vehicle.nick) }
                Field(label: "Plate") { TextField("ABC 123", text: $vehicle.plate).textInputAutocapitalization(.characters) }
            }
            Field(label: "VIN") { TextField("17 characters", text: $vehicle.vin).textInputAutocapitalization(.characters) }
            Eyebrow("When you got it").padding(.top, 6)
            HStack(spacing: 10) {
                DateField(label: "Date", key: $vehicle.bought)
                Field(label: "\(store.distUnit) then") { TextField("0", text: $milesText).keyboardType(.numberPad) }
                MoneyField(label: "Paid", value: $vehicle.boughtPrice)
            }
            Eyebrow("Glovebox dates").padding(.top, 6)
            HStack(spacing: 10) { DateField(label: "Insurance renews", key: $vehicle.insurance); DateField(label: "Registration", key: $vehicle.registration) }
            HStack(spacing: 10) { DateField(label: "Inspection due", key: $vehicle.inspection); DateField(label: "Warranty ends", key: $vehicle.warranty) }
            Toggle(isOn: $vehicle.remind) {
                VStack(alignment: .leading, spacing: 2) { Text("Remind me 14 days before").font(.ui(14, .heavy)).foregroundStyle(Dash.cream); Text("A local notification. Nothing leaves the phone.").font(.ui(11.5, .medium)).foregroundStyle(Dash.dim) }
            }.tint(Dash.amber).tile(padding: 14, radius: 14)
            AmberButton(title: isNew ? "Add to garage" : "Save") {
                vehicle.boughtMiles = store.fromDisplay(Int(milesText) ?? 0)
                if vehicle.make.isEmpty && vehicle.model.isEmpty && vehicle.nick.isEmpty { vehicle.model = "My car" }
                store.upsert(vehicle); dismiss()
            }
            if !isNew {
                Button(role: .destructive) { store.delete(vehicle); dismiss() } label: { Text("Delete this vehicle and everything logged for it").font(.ui(13, .heavy)).foregroundStyle(Dash.red).frame(maxWidth: .infinity).padding(.vertical, 8) }
            }
        }.onAppear { milesText = vehicle.boughtMiles > 0 ? "\(store.toDisplay(vehicle.boughtMiles))" : "" }
    }
}

struct DateField: View {
    let label: String
    @Binding var key: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(label)
            HStack {
                DatePicker("", selection: Binding(get: { key.isEmpty ? .now : Day.date(key) }, set: { key = Day.key($0) }), displayedComponents: .date).labelsHidden().tint(Dash.amber).colorScheme(.dark)
                Spacer()
                if !key.isEmpty { Button { key = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Dash.dim) }.buttonStyle(.plain) }
                else { Text("not set").font(.ui(11, .heavy)).foregroundStyle(Dash.dim) }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Dash.bg2)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Dash.line2))
        }
    }
}

struct MoneyField: View {
    @Environment(Store.self) private var store
    let label: String
    @Binding var value: Double
    @State private var text = ""
    var body: some View {
        Field(label: label) {
            HStack(spacing: 4) { Text(store.settings.currency).foregroundStyle(Dash.dim); TextField("0", text: $text).keyboardType(.decimalPad).onChange(of: text) { _, n in value = Double(n) ?? 0 } }
        }.onAppear { text = value == 0 ? "" : (value == value.rounded() ? "\(Int(value))" : String(format: "%.2f", value)) }
    }
}

struct MilesField: View {
    @Environment(Store.self) private var store
    let label: String
    @Binding var miles: Int
    @State private var text = ""
    var body: some View {
        Field(label: label) { TextField("0", text: $text).keyboardType(.numberPad).onChange(of: text) { _, n in miles = store.fromDisplay(Int(n) ?? 0) } }
            .onAppear { text = miles == 0 ? "" : "\(store.toDisplay(miles))" }
    }
}

struct FuelEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var fuel: Fuel?
    @State private var date = Day.today
    @State private var miles = 0
    @State private var volText = ""
    @State private var priceText = ""
    @State private var full = true
    var body: some View {
        let v = store.car!
        let vol = store.galFromDisplay(Double(volText) ?? 0), price = Double(priceText) ?? 0
        SheetPage(title: fuel == nil ? "Fill-up" : "Edit fill-up") {
            HStack(spacing: 10) { DateField(label: "Date", key: $date); MilesField(label: "Odometer (\(store.distUnit))", miles: $miles) }
            HStack(spacing: 10) {
                Field(label: store.settings.litres ? "Litres" : "Gallons") { TextField("0.0", text: $volText).keyboardType(.decimalPad) }
                MoneyText(label: "Total paid", text: $priceText)
            }
            if vol > 0 && price > 0 {
                HStack { Eyebrow("That is"); Spacer(); Text("\(store.money2(price / store.galToDisplay(vol))) per \(store.volUnit)").font(.num(13)).foregroundStyle(Dash.amber) }.padding(.horizontal, 4)
            }
            Toggle(isOn: $full) {
                VStack(alignment: .leading, spacing: 2) { Text("Filled the tank").font(.ui(14, .heavy)).foregroundStyle(Dash.cream); Text("Economy is measured from one full tank to the next.").font(.ui(11.5, .medium)).foregroundStyle(Dash.dim) }
            }.tint(Dash.amber).tile(padding: 14, radius: 14)
            AmberButton(title: "Save", icon: "fuelpump.fill") {
                var f = fuel ?? Fuel(vehicle: v.id, date: date, miles: miles, gallons: 0, price: 0)
                f.date = date; f.miles = miles; f.gallons = vol; f.price = price; f.full = full
                if let i = store.fuel.firstIndex(where: { $0.id == f.id }) { store.fuel[i] = f } else { store.fuel.append(f) }
                store.save(); dismiss()
            }
            if fuel != nil { Button(role: .destructive) { store.fuel.removeAll { $0.id == fuel!.id }; store.save(); dismiss() } label: { Text("Delete").font(.ui(13, .heavy)).foregroundStyle(Dash.red).frame(maxWidth: .infinity).padding(.vertical, 8) } }
        }.onAppear {
            if let f = fuel { date = f.date; miles = f.miles; volText = String(format: "%.2f", store.galToDisplay(f.gallons)); priceText = String(format: "%.2f", f.price); full = f.full }
            else { miles = store.miles(v) }
        }
    }
}

struct MoneyText: View {
    @Environment(Store.self) private var store
    let label: String
    @Binding var text: String
    var body: some View { Field(label: label) { HStack(spacing: 4) { Text(store.settings.currency).foregroundStyle(Dash.dim); TextField("0.00", text: $text).keyboardType(.decimalPad) } } }
}

struct ServiceEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var service: Service?
    @State private var date = Day.today
    @State private var miles = 0
    @State private var type = "oil"
    @State private var customName = ""
    @State private var diy = false
    @State private var shop = ""
    @State private var parts = 0.0
    @State private var labor = 0.0
    @State private var note = ""
    var body: some View {
        let v = store.car!
        let options: [(String, String)] = Template.all.filter { !v.hidden.contains($0.key) }.map { ($0.key, $0.name) } + v.custom.map { ($0.id.uuidString, $0.name) } + [("__other", "Something else")]
        SheetPage(title: service == nil ? "Log a service" : "Edit service") {
            Eyebrow("What was done")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(options, id: \.0) { o in
                    let on = type == o.0 || (o.0 == "__other" && !options.contains { $0.0 == type })
                    Button { type = o.0 == "__other" ? (customName.isEmpty ? "__other" : customName) : o.0 } label: {
                        Text(o.1).font(.ui(12.5, .heavy)).foregroundStyle(on ? Dash.bg : Dash.cream).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? Dash.amber : Dash.bg2)).overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(on ? Dash.amber : Dash.line2))
                    }.buttonStyle(.plain)
                }
            }
            if !options.contains(where: { $0.0 == type }) {
                Field(label: "Name it") { TextField("Brake pads, front", text: $customName).onChange(of: customName) { _, n in type = n.isEmpty ? "__other" : n } }
            }
            HStack(spacing: 10) { DateField(label: "Date", key: $date); MilesField(label: "Odometer (\(store.distUnit))", miles: $miles) }
            HStack(spacing: 0) {
                ForEach([false, true], id: \.self) { d in
                    Button { diy = d } label: {
                        Text(d ? "Did it myself" : "At a shop").font(.ui(13, .heavy)).foregroundStyle(diy == d ? Dash.bg : Dash.grey).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Group { if diy == d { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Dash.amber) } })
                    }.buttonStyle(.plain)
                }
            }.padding(3).background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Dash.card)).overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Dash.line2))
            if !diy { Field(label: "Shop") { TextField("Toyota of Dayton", text: $shop) } }
            HStack(spacing: 10) { MoneyField(label: "Parts", value: $parts); MoneyField(label: diy ? "Other costs" : "Labor", value: $labor) }
            Field(label: "Note") { TextField("Synthetic 0W-20, also topped washer fluid", text: $note, axis: .vertical).lineLimit(2...4) }
            AmberButton(title: "Save", icon: "wrench.fill") {
                var s = service ?? Service(vehicle: v.id, date: date, miles: miles, type: type)
                s.date = date; s.miles = miles; s.type = type == "__other" ? "Service" : type; s.diy = diy; s.shop = diy ? "" : shop; s.parts = parts; s.labor = labor; s.note = note
                if let i = store.services.firstIndex(where: { $0.id == s.id }) { store.services[i] = s } else { store.services.append(s) }
                store.save(); dismiss()
            }
            if service != nil, store.services.contains(where: { $0.id == service!.id }) { Button(role: .destructive) { store.services.removeAll { $0.id == service!.id }; store.save(); dismiss() } label: { Text("Delete").font(.ui(13, .heavy)).foregroundStyle(Dash.red).frame(maxWidth: .infinity).padding(.vertical, 8) } }
        }.onAppear {
            if let s = service { date = s.date; miles = s.miles; type = s.type; diy = s.diy; shop = s.shop; parts = s.parts; labor = s.labor; note = s.note; if !options.contains(where: { $0.0 == s.type }) { customName = s.type } }
            else { miles = store.miles(v) }
        }
    }
}

struct ExpenseEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var expense: Expense?
    @State private var date = Day.today
    @State private var kind = ExpenseKind.insurance
    @State private var amount = 0.0
    @State private var note = ""
    var body: some View {
        let v = store.car!
        SheetPage(title: expense == nil ? "Add an expense" : "Edit expense") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ExpenseKind.allCases, id: \.self) { k in
                    Button { kind = k } label: {
                        Text(k.rawValue).font(.ui(12.5, .heavy)).foregroundStyle(kind == k ? Dash.bg : Dash.cream).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(kind == k ? Dash.amber : Dash.bg2)).overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(kind == k ? Dash.amber : Dash.line2))
                    }.buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) { DateField(label: "Date", key: $date); MoneyField(label: "Amount", value: $amount) }
            Field(label: "Note") { TextField("6-month premium", text: $note) }
            AmberButton(title: "Save", icon: "creditcard.fill") {
                var e = expense ?? Expense(vehicle: v.id, date: date, kind: kind, amount: amount)
                e.date = date; e.kind = kind; e.amount = amount; e.note = note
                if let i = store.expenses.firstIndex(where: { $0.id == e.id }) { store.expenses[i] = e } else { store.expenses.append(e) }
                store.save(); dismiss()
            }
            if expense != nil { Button(role: .destructive) { store.expenses.removeAll { $0.id == expense!.id }; store.save(); dismiss() } label: { Text("Delete").font(.ui(13, .heavy)).foregroundStyle(Dash.red).frame(maxWidth: .infinity).padding(.vertical, 8) } }
        }.onAppear { if let e = expense { date = e.date; kind = e.kind; amount = e.amount; note = e.note } }
    }
}

struct ReadingSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focus: Bool
    var body: some View {
        let v = store.car!
        let n = Int(text) ?? store.toDisplay(store.miles(v))
        SheetPage(title: "Odometer") {
            Text("Type what the dash says. Every reading sharpens the pace, and the pace predicts when things are due.").font(.ui(13, .medium)).foregroundStyle(Dash.grey)
            HStack { Spacer(); OdoRoller(value: n, size: 40); Spacer() }.padding(.vertical, 10)
            Field(label: "Reading in \(store.distUnit)") { TextField("\(store.toDisplay(store.miles(v)))", text: $text).keyboardType(.numberPad).focused($focus).font(.num(24)) }
            if store.fromDisplay(n) < store.miles(v) { Text("That is lower than the last reading of \(store.dist(store.miles(v))).").font(.ui(12, .heavy)).foregroundStyle(Dash.red) }
            AmberButton(title: "Save reading") { let m = store.fromDisplay(n); if m > 0 { store.setMiles(v, m) }; dismiss() }
        }.onAppear { focus = true }
    }
}

struct IntervalsSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var newMiles = ""
    @State private var newMonths = ""
    var body: some View {
        @Bindable var store = store
        let v = store.car!
        SheetPage(title: "Intervals") {
            Text("How often each job comes round for this car. Check the owner's manual; these are common defaults. Switch off jobs this car does not have.").font(.ui(13, .medium)).foregroundStyle(Dash.grey)
            ForEach(Template.all) { t in IntervalRow(key: t.key, name: t.name, defaults: Interval(miles: t.miles, months: t.months), hideable: true) }
            ForEach(v.custom) { c in IntervalRow(key: c.id.uuidString, name: c.name, defaults: Interval(miles: c.miles, months: c.months), hideable: false) }
            Eyebrow("Add your own job").padding(.top, 8)
            Field(label: "Name") { TextField("Differential fluid", text: $newName) }
            HStack(spacing: 10) {
                Field(label: "Every \(store.distUnit)") { TextField("30000", text: $newMiles).keyboardType(.numberPad) }
                Field(label: "Every months") { TextField("36", text: $newMonths).keyboardType(.numberPad) }
            }
            GreyButton(title: "Add job", icon: "plus") {
                guard !newName.isEmpty, var car = store.car else { return }
                car.custom.append(CustomItem(name: newName, miles: store.fromDisplay(Int(newMiles) ?? 0), months: Int(newMonths) ?? 0)); store.upsert(car)
                newName = ""; newMiles = ""; newMonths = ""
            }
            AmberButton(title: "Done") { dismiss() }
        }
    }
}

struct IntervalRow: View {
    @Environment(Store.self) private var store
    let key: String, name: String, defaults: Interval, hideable: Bool
    @State private var miles = ""
    @State private var months = ""
    var body: some View {
        let v = store.car!, hidden = v.hidden.contains(key)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.ui(13.5, .heavy)).foregroundStyle(hidden ? Dash.dim : Dash.cream).lineLimit(1)
                Text(defaults.miles > 0 || defaults.months > 0 ? "default \(defaults.miles > 0 ? store.dist(defaults.miles) : "") \(defaults.months > 0 ? "/ \(defaults.months) mo" : "")" : "").font(.ui(10.5, .medium)).foregroundStyle(Dash.dim)
            }
            Spacer()
            TextField(store.distUnit, text: $miles).keyboardType(.numberPad).font(.num(13)).foregroundStyle(Dash.cream).multilineTextAlignment(.center).frame(width: 66).padding(.vertical, 7).background(RoundedRectangle(cornerRadius: 8).fill(Dash.bg2)).disabled(hidden)
                .onChange(of: miles) { _, n in commit() }
            TextField("mo", text: $months).keyboardType(.numberPad).font(.num(13)).foregroundStyle(Dash.cream).multilineTextAlignment(.center).frame(width: 46).padding(.vertical, 7).background(RoundedRectangle(cornerRadius: 8).fill(Dash.bg2)).disabled(hidden)
                .onChange(of: months) { _, n in commit() }
            if hideable {
                Button { var c = v; if hidden { c.hidden.removeAll { $0 == key } } else { c.hidden.append(key) }; store.upsert(c) } label: {
                    Image(systemName: hidden ? "eye.slash" : "eye").font(.system(size: 13, weight: .bold)).foregroundStyle(hidden ? Dash.dim : Dash.amber).frame(width: 30)
                }.buttonStyle(.plain)
            } else {
                Button { var c = v; c.custom.removeAll { $0.id.uuidString == key }; store.upsert(c) } label: { Image(systemName: "trash").font(.system(size: 13, weight: .bold)).foregroundStyle(Dash.red).frame(width: 30) }.buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4).opacity(hidden ? 0.6 : 1)
        .onAppear { let iv = store.interval(v, key); miles = iv.miles > 0 ? "\(store.toDisplay(iv.miles))" : ""; months = iv.months > 0 ? "\(iv.months)" : "" }
    }
    func commit() {
        guard var c = store.car else { return }
        let iv = Interval(miles: store.fromDisplay(Int(miles) ?? 0), months: Int(months) ?? 0)
        if let ci = c.custom.firstIndex(where: { $0.id.uuidString == key }) { c.custom[ci].miles = iv.miles; c.custom[ci].months = iv.months }
        else if iv == defaults { c.overrides[key] = nil } else { c.overrides[key] = iv }
        store.vehicles[store.vehicles.firstIndex { $0.id == c.id }!] = c; store.save()
    }
}

struct SettingsSheet: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var store = store
        SheetPage(title: "Settings") {
            VStack(spacing: 0) {
                Toggle(isOn: $store.settings.metric) { Text("Kilometres instead of miles").font(.ui(14, .heavy)).foregroundStyle(Dash.cream) }.tint(Dash.amber).padding(.vertical, 10)
                Divider().overlay(Dash.line)
                Toggle(isOn: $store.settings.litres) { Text("Litres instead of gallons").font(.ui(14, .heavy)).foregroundStyle(Dash.cream) }.tint(Dash.amber).padding(.vertical, 10)
                Divider().overlay(Dash.line)
                HStack {
                    Text("Currency symbol").font(.ui(14, .heavy)).foregroundStyle(Dash.cream); Spacer()
                    HStack(spacing: 6) {
                        ForEach(["$", "€", "£", "¥", "₹", "A$", "C$"], id: \.self) { c in
                            Button { store.settings.currency = c } label: { Text(c).font(.num(13)).foregroundStyle(store.settings.currency == c ? Dash.bg : Dash.grey).frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 8).fill(store.settings.currency == c ? Dash.amber : Dash.bg2)) }.buttonStyle(.plain)
                        }
                    }
                }.padding(.vertical, 10)
            }.tile(padding: 14)
            .onChange(of: store.settings.metric) { _, _ in store.save() }.onChange(of: store.settings.litres) { _, _ in store.save() }.onChange(of: store.settings.currency) { _, _ in store.save() }
            ProCard()
            if let v = store.car {
                Eyebrow("Export").padding(.top, 6)
                if pro.unlocked {
                    ShareLink(item: csvURL(v)) {
                        HStack { Image(systemName: "tablecells").foregroundStyle(Dash.amber); Text("CSV of everything for \(v.title)").font(.ui(14, .heavy)).foregroundStyle(Dash.cream); Spacer(); Image(systemName: "square.and.arrow.up").foregroundStyle(Dash.dim) }.tile(padding: 14, radius: 14)
                    }
                } else {
                    Button { pro.ask(.export) } label: {
                        HStack { Image(systemName: "tablecells").foregroundStyle(Dash.amber); Text("CSV of everything for \(v.title)").font(.ui(14, .heavy)).foregroundStyle(Dash.cream); Spacer(); Image(systemName: "lock.fill").foregroundStyle(Dash.dim) }.tile(padding: 14, radius: 14)
                    }.buttonStyle(.plain)
                }
            }
            Text("Everything is stored on this phone in a single file. Nothing is sent anywhere.").font(.ui(12, .medium)).foregroundStyle(Dash.dim)
            AmberButton(title: "Done") { dismiss() }
        }
    }
    func csvURL(_ v: Vehicle) -> URL {
        let u = URL.temporaryDirectory.appending(path: "odometer-\(v.title.replacingOccurrences(of: " ", with: "-")).csv")
        try? store.csv(v).data(using: .utf8)?.write(to: u); return u
    }
}

// MARK: Service history (PDF)

struct HistorySheet: View {
    @Environment(Store.self) private var store
    @State private var pdf: URL? = nil
    var body: some View {
        let v = store.car!
        SheetPage(title: "Service history") {
            Text("The document a buyer wants to see. Share it as a PDF.").font(.ui(13, .medium)).foregroundStyle(Dash.grey)
            if let pdf { ShareLink(item: pdf) { HStack { Image(systemName: "square.and.arrow.up"); Text("Share PDF") }.font(.ui(15, .heavy)).foregroundStyle(Dash.bg).frame(maxWidth: .infinity).padding(.vertical, 14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Dash.amber)) } }
            DocPreview { HistoryDoc(vehicle: v).environment(store) }
        }
        .task { pdf = await render(v) }
    }
    @MainActor func render(_ v: Vehicle) async -> URL? {
        let doc = HistoryDoc(vehicle: v).environment(store)
        let r = ImageRenderer(content: doc.frame(width: 612))
        r.proposedSize = .init(width: 612, height: nil)
        let u = URL.temporaryDirectory.appending(path: "\(v.title.replacingOccurrences(of: " ", with: "-"))-service-history.pdf")
        var ok = false
        r.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let ctx = CGContext(u as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF(); ok = true
        }
        return ok ? u : nil
    }
}

struct HistoryDoc: View {
    @Environment(Store.self) private var store
    let vehicle: Vehicle
    var body: some View {
        let v = vehicle
        let svcs = store.services.filter { $0.vehicle == v.id }.sorted { ($0.date, $0.miles) < ($1.date, $1.miles) }
        let total = svcs.map { $0.cost }.reduce(0, +)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SERVICE HISTORY").font(.system(size: 9, weight: .black)).tracking(2).foregroundStyle(Color(red: 0.55, green: 0.3, blue: 0.1))
                    Text(v.longTitle).font(.system(size: 20, weight: .heavy, design: .serif)).foregroundStyle(.black)
                    Text("VIN \(v.vin.isEmpty ? "not recorded" : v.vin) · plate \(v.plate.isEmpty ? "n/a" : v.plate)").font(.system(size: 9, weight: .medium)).foregroundStyle(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(store.dist(store.miles(v)))").font(.system(size: 16, weight: .heavy, design: .monospaced)).foregroundStyle(.black)
                    Text("as of \(Day.pretty(Day.today))").font(.system(size: 8, weight: .medium)).foregroundStyle(.gray)
                }
            }
            Rectangle().fill(.black).frame(height: 1.5)
            HStack(spacing: 18) {
                DocStat(label: "Services", value: "\(svcs.count)")
                DocStat(label: "Spent on upkeep", value: store.money(total))
                DocStat(label: "Owned since", value: v.bought.isEmpty ? "–" : Day.pretty(v.bought))
                DocStat(label: "Average \(store.econUnit)", value: store.econ(store.avgMpg(v)))
            }
            HStack(spacing: 6) {
                Text("Date").frame(width: 68, alignment: .leading); Text(store.distUnit.uppercased()).frame(width: 52, alignment: .trailing); Text("Work done").frame(maxWidth: .infinity, alignment: .leading); Text("Where").frame(width: 92, alignment: .leading); Text("Cost").frame(width: 48, alignment: .trailing)
            }.font(.system(size: 7.5, weight: .black)).foregroundStyle(.gray).padding(.top, 4)
            ForEach(svcs) { s in
                HStack(alignment: .top, spacing: 6) {
                    Text(Day.short(s.date) + " " + String(s.date.prefix(4))).frame(width: 68, alignment: .leading)
                    Text(store.distShort(s.miles)).font(.system(size: 8.5, weight: .semibold, design: .monospaced)).frame(width: 52, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 1) { Text(store.typeName(v, s.type)).fontWeight(.bold); if !s.note.isEmpty { Text(s.note).foregroundStyle(.gray) } }.frame(maxWidth: .infinity, alignment: .leading)
                    Text(s.diy ? "Owner" : s.shop).frame(width: 92, alignment: .leading).lineLimit(2)
                    Text(store.money(s.cost)).frame(width: 48, alignment: .trailing)
                }.font(.system(size: 8.5, weight: .medium)).foregroundStyle(.black).padding(.vertical, 3)
                Rectangle().fill(Color.black.opacity(0.12)).frame(height: 0.5)
            }
            if svcs.isEmpty { Text("No services logged yet.").font(.system(size: 9)).foregroundStyle(.gray) }
            Text("Produced with Odometer. Records entered by the owner.").font(.system(size: 7, weight: .medium)).foregroundStyle(.gray).padding(.top, 8)
        }
        .padding(28).frame(width: 612, alignment: .topLeading).background(Color(red: 0.99, green: 0.98, blue: 0.96))
    }
}

struct DocHeightKey: PreferenceKey { static var defaultValue: CGFloat = 0; static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) } }

/// Shows a 612pt-wide document scaled to the phone's width.
struct DocPreview<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 400
    var body: some View {
        let w = UIScreen.main.bounds.width - 36
        let s = w / 612
        content
            .background(GeometryReader { g in Color.clear.preference(key: DocHeightKey.self, value: g.size.height) })
            .onPreferenceChange(DocHeightKey.self) { height = $0 }
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: w, height: height * s, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 10)).shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
}

struct DocStat: View {
    let label: String, value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) { Text(label.uppercased()).font(.system(size: 7, weight: .black)).tracking(1).foregroundStyle(.gray); Text(value).font(.system(size: 12, weight: .heavy)).foregroundStyle(.black) }
    }
}
