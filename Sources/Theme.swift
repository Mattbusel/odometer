import SwiftUI

/// Gunmetal and oil-orange. A vintage dashboard: rolling digits, warm gauges, embossed plates.
enum Dash {
    static let bg = Color(red: 0.071, green: 0.078, blue: 0.071)         // #121412
    static let bg2 = Color(red: 0.094, green: 0.102, blue: 0.094)
    static let card = Color(red: 0.118, green: 0.129, blue: 0.118)
    static let card2 = Color(red: 0.16, green: 0.17, blue: 0.16)
    static let line = Color.white.opacity(0.07)
    static let line2 = Color.white.opacity(0.16)
    static let cream = Color(red: 0.953, green: 0.937, blue: 0.902)
    static let grey = Color(red: 0.953, green: 0.937, blue: 0.902).opacity(0.62)
    static let dim = Color(red: 0.953, green: 0.937, blue: 0.902).opacity(0.34)
    static let amber = Color(red: 0.949, green: 0.639, blue: 0.227)      // #F2A33A
    static let orange = Color(red: 0.91, green: 0.388, blue: 0.169)      // #E8632B
    static let ok = Color(red: 0.435, green: 0.749, blue: 0.451)
    static let red = Color(red: 0.898, green: 0.282, blue: 0.302)
    static let blue = Color(red: 0.42, green: 0.66, blue: 0.86)
    static let plate = Color(red: 0.86, green: 0.83, blue: 0.74)
    static let plateInk = Color(red: 0.13, green: 0.16, blue: 0.24)
}

extension Font {
    static func big(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func ui(_ size: CGFloat, _ w: Font.Weight = .semibold) -> Font { .system(size: size, weight: w, design: .rounded) }
    static func num(_ size: CGFloat, _ w: Font.Weight = .heavy) -> Font { .system(size: size, weight: w, design: .rounded).monospacedDigit() }
    static func mono(_ size: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: size, weight: w, design: .monospaced) }
}

struct DashBackground: View {
    var body: some View {
        ZStack {
            Dash.bg
            RadialGradient(colors: [Dash.orange.opacity(0.14), .clear], center: .init(x: 0.85, y: -0.05), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Dash.amber.opacity(0.06), .clear], center: .init(x: 0.0, y: 1.1), startRadius: 10, endRadius: 420)
        }.ignoresSafeArea()
    }
}

struct Eyebrow: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text.uppercased()).font(.ui(11, .heavy)).tracking(2).foregroundStyle(Dash.dim) }
}

extension View {
    func tile(padding: CGFloat = 16, radius: CGFloat = 20) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Dash.card))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Dash.line))
    }
}

struct AmberButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .black)) }
                Text(title).font(.ui(15, .heavy))
            }
            .foregroundStyle(Dash.bg).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient(colors: [Dash.amber, Dash.orange], startPoint: .leading, endPoint: .trailing)).shadow(color: Dash.orange.opacity(0.35), radius: 16, y: 6))
        }.buttonStyle(.plain)
    }
}

struct GreyButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title).font(.ui(13, .heavy))
            }
            .foregroundStyle(Dash.grey).padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Dash.card2)).overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Dash.line2))
        }.buttonStyle(.plain)
    }
}

/// An embossed licence plate.
struct Plate: View {
    let text: String
    var small = false
    var body: some View {
        Text(text.isEmpty ? "NO PLATE" : text.uppercased()).font(.mono(small ? 11 : 14, .black)).tracking(1.5).foregroundStyle(Dash.plateInk)
            .padding(.horizontal, small ? 7 : 10).padding(.vertical, small ? 3 : 5)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LinearGradient(colors: [Dash.plate, Dash.plate.opacity(0.85)], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Dash.plateInk.opacity(0.5), lineWidth: 1.5))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.white.opacity(0.4), lineWidth: 1).padding(2))
            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
    }
}

/// A mechanical odometer: each digit is a wheel that rolls to its value.
struct OdoRoller: View {
    let value: Int
    var digits = 6
    var size: CGFloat = 34
    var body: some View {
        let s = String(format: "%0\(digits)d", max(0, min(value, Int(pow(10.0, Double(digits))) - 1)))
        HStack(spacing: 3) {
            ForEach(Array(s.enumerated()), id: \.offset) { pair in
                DigitWheel(digit: Int(String(pair.element)) ?? 0, size: size, last: pair.offset == digits - 1)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Dash.line2))
    }
}

struct DigitWheel: View {
    let digit: Int
    let size: CGFloat
    var last = false
    var body: some View {
        let h = size * 1.3
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(last ? Dash.cream : Color(red: 0.16, green: 0.16, blue: 0.15))
            Color.clear.frame(width: size * 0.78, height: h).overlay(
                VStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { d in
                        Text("\(d)").font(.mono(size, .black)).foregroundStyle(last ? Dash.bg : Dash.cream).frame(width: size * 0.78, height: h)
                    }
                }
                .offset(y: -CGFloat(digit) * h + h * 4.5)
                .animation(.spring(duration: 0.9, bounce: 0.15), value: digit)
            )
            LinearGradient(colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
        }
        .frame(width: size * 0.78, height: h).clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// A gauge arc: how much of an interval has been used.
struct DialGauge: View {
    let fraction: Double
    let color: Color
    var size: CGFloat = 54
    var lineWidth: CGFloat = 7
    var body: some View {
        ZStack {
            Circle().trim(from: 0.0, to: 0.75).stroke(Dash.line2, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)).rotationEffect(.degrees(135))
            Circle().trim(from: 0.0, to: 0.75 * min(1.0, max(0.0, fraction))).stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)).rotationEffect(.degrees(135))
                .animation(.spring(duration: 0.7), value: fraction)
            Text("\(Int((min(1.0, max(0.0, fraction)) * 100).rounded()))%").font(.num(size * 0.24)).foregroundStyle(Dash.cream)
        }
        .frame(width: size, height: size)
    }
}

extension DueStatus {
    var color: Color { switch self { case .ok: return Dash.ok; case .soon: return Dash.amber; case .overdue: return Dash.red } }
}

struct StatusPill: View {
    let status: DueStatus
    var body: some View {
        Text(status.label).font(.ui(10, .black)).tracking(1).foregroundStyle(status == .ok ? Dash.ok : Dash.bg)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(status == .ok ? Dash.ok.opacity(0.14) : status.color))
    }
}

struct DashTabBar: View {
    @Binding var selection: Tab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(.snappy(duration: 0.25)) { selection = t } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: t.icon).font(.system(size: 17, weight: selection == t ? .black : .medium))
                        Text(t.rawValue).font(.ui(10, .heavy))
                    }
                    .foregroundStyle(selection == t ? Dash.bg : Dash.dim)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Group { if selection == t { RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Dash.amber) } })
                }.buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 19, style: .continuous).fill(Dash.card).shadow(color: .black.opacity(0.6), radius: 20, y: 10))
        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).strokeBorder(Dash.line2))
        .padding(.horizontal, 16)
    }
}

struct Field<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(label)
            content.font(.ui(16, .semibold)).foregroundStyle(Dash.cream).padding(.horizontal, 12).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Dash.bg2)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Dash.line2))
        }
    }
}

struct Stat: View {
    let label: String
    let value: String
    var sub: String = ""
    var color: Color = Dash.cream
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(label)
            Text(value).font(.num(22)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            if !sub.isEmpty { Text(sub).font(.ui(11, .medium)).foregroundStyle(Dash.dim).lineLimit(2) }
        }.frame(maxWidth: .infinity, alignment: .leading).tile(padding: 13, radius: 16)
    }
}
