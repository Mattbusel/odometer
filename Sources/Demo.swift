import Foundation

enum Demo {
    static func fill(_ s: Store) {
        let t = Day.today
        var rav = Vehicle(year: "2019", make: "Toyota", model: "RAV4 XLE", nick: "", plate: "8KLM 442", vin: "2T3P1RFV4KW041873", bought: Day.add(t, -792), boughtPrice: 24800, boughtMiles: 31200,
                          insurance: Day.add(t, 41), registration: Day.add(t, 116), inspection: Day.add(t, 118), warranty: Day.add(t, 303), remind: true)
        rav.hidden = ["timing"]
        let civic = Vehicle(year: "2015", make: "Honda", model: "Civic LX", nick: "", plate: "KTP 2081", vin: "19XFB2F52FE203311", bought: Day.add(t, -1500), boughtPrice: 11500, boughtMiles: 62000,
                            insurance: Day.add(t, 41), registration: Day.add(t, -12), inspection: Day.add(t, 200), warranty: "", remind: false)
        let miata = Vehicle(year: "1998", make: "Mazda", model: "MX-5 Miata", nick: "The Miata", plate: "MIATA98", vin: "JM1NB3532W0142518", bought: Day.add(t, -420), boughtPrice: 6200, boughtMiles: 118400,
                            insurance: Day.add(t, 210), registration: Day.add(t, 60), inspection: "", warranty: "", remind: false)
        s.vehicles = [rav, civic, miata]; s.current = rav.id

        var seed: UInt64 = 11
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33 % 1000) / 1000 }

        // RAV4: 26 months of fill-ups every ~9 days, ~330 mi per tank, price drifting.
        var miles = 31200, day = -790
        var last = 0
        while day < 0 {
            let gap = 7 + Int(rnd() * 5); day += gap
            if day >= 0 { break }
            let d = 240 + Int(rnd() * 130); miles += d
            let gal = Double(d) / (30.5 + rnd() * 4); let ppg = 3.15 + rnd() * 0.75
            s.fuel.append(Fuel(vehicle: rav.id, date: Day.add(t, day), miles: miles, gallons: (gal * 100).rounded() / 100, price: (gal * ppg * 100).rounded() / 100, full: rnd() > 0.1))
            last = miles
        }
        let now = last + 120
        s.readings.append(Reading(vehicle: rav.id, date: Day.add(t, -2), miles: now))
        func svc(_ v: UUID, _ dayAgo: Int, _ mi: Int, _ type: String, _ shop: String, _ parts: Double, _ labor: Double, _ note: String = "") {
            s.services.append(Service(vehicle: v, date: Day.add(t, -dayAgo), miles: mi, type: type, diy: shop.isEmpty, shop: shop, parts: parts, labor: labor, note: note))
        }
        // RAV4 services: oil every ~5k, rotations, filters, brake fluid, wipers; cabin filter and wipers overdue.
        svc(rav.id, 745, 32100, "oil", "Toyota of Dayton", 38, 41, "Synthetic 0W-20")
        svc(rav.id, 745, 32100, "tires", "Toyota of Dayton", 0, 25)
        svc(rav.id, 630, 36018, "cabin", "", 19, 0, "Bought the filter online, took ten minutes")
        svc(rav.id, 600, 37000, "oil", "Toyota of Dayton", 38, 41)
        svc(rav.id, 540, 38933, "wipers", "", 34, 0, "Bosch Icon, both sides")
        svc(rav.id, 450, 42000, "oil", "Valvoline Express", 45, 30)
        svc(rav.id, 450, 42000, "tires", "Valvoline Express", 0, 20)
        svc(rav.id, 447, 41845, "brakefluid", "Toyota of Dayton", 22, 89, "Flushed at the 40k service")
        svc(rav.id, 300, 46039, "engine", "", 24, 0)
        svc(rav.id, 290, 47100, "oil", "Valvoline Express", 45, 30)
        svc(rav.id, 150, 51200, "oil", "Toyota of Dayton", 41, 44, "Also topped washer fluid")
        svc(rav.id, 150, 51200, "tires", "Toyota of Dayton", 0, 25)
        svc(rav.id, 52, now - 2100, "oil", "Valvoline Express", 46, 32)
        svc(rav.id, 52, now - 2100, "tires", "Valvoline Express", 0, 20)
        svc(rav.id, 20, now - 500, "battery", "AutoZone", 189, 0, "Original battery tested weak at 5 years")
        // RAV4 expenses.
        for m in 0..<26 {
            let dd = -m * 30 - 4
            if m % 6 == 0 { s.expenses.append(Expense(vehicle: rav.id, date: Day.add(t, dd), kind: .insurance, amount: 612, note: "6-month premium")) }
            if m % 12 == 3 { s.expenses.append(Expense(vehicle: rav.id, date: Day.add(t, dd), kind: .registration, amount: 98, note: "Ohio BMV")) }
            if rnd() > 0.5 { s.expenses.append(Expense(vehicle: rav.id, date: Day.add(t, dd + 9), kind: .wash, amount: 12)) }
            if rnd() > 0.6 { s.expenses.append(Expense(vehicle: rav.id, date: Day.add(t, dd + 14), kind: .tolls, amount: (8 + rnd() * 20).rounded())) }
            if rnd() > 0.7 { s.expenses.append(Expense(vehicle: rav.id, date: Day.add(t, dd + 20), kind: .parking, amount: (6 + rnd() * 30).rounded())) }
        }
        // Civic: a few entries.
        svc(civic.id, 200, 95200, "oil", "Jiffy Lube", 40, 35)
        svc(civic.id, 200, 95200, "tires", "Jiffy Lube", 0, 20)
        svc(civic.id, 400, 92500, "brakefluid", "Honda of Kettering", 20, 95)
        s.readings.append(Reading(vehicle: civic.id, date: Day.add(t, -5), miles: 97050))
        var cm = 93000
        for i in stride(from: 26, through: 1, by: -1) { cm += 150 + Int(rnd() * 90); s.fuel.append(Fuel(vehicle: civic.id, date: Day.add(t, -i * 14), miles: cm, gallons: (Double(cm) * 0 + 8.4 + rnd() * 2).rounded(), price: 31 + (rnd() * 9).rounded(), full: true)) }
        s.expenses.append(Expense(vehicle: civic.id, date: Day.add(t, -100), kind: .insurance, amount: 388, note: "6-month premium"))
        // Miata: weekend car.
        svc(miata.id, 380, 118600, "oil", "", 42, 0, "Mobil 1 10W-30, Mazda filter")
        svc(miata.id, 380, 118600, "timing", "Miata Garage", 220, 480, "Belt, water pump, seals")
        svc(miata.id, 90, 119900, "plugs", "", 36, 0, "NGK, gapped to 0.040")
        s.readings.append(Reading(vehicle: miata.id, date: Day.add(t, -9), miles: 120310))
        var mm = 118500
        for i in stride(from: 12, through: 1, by: -1) { mm += 120 + Int(rnd() * 80); s.fuel.append(Fuel(vehicle: miata.id, date: Day.add(t, -i * 30), miles: mm, gallons: 8 + (rnd() * 3).rounded(), price: 30 + (rnd() * 12).rounded(), full: true)) }
        s.expenses.append(Expense(vehicle: miata.id, date: Day.add(t, -200), kind: .insurance, amount: 210, note: "Classic policy"))
    }
}
