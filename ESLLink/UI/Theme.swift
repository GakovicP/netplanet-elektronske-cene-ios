import SwiftUI
import AudioToolbox

extension Color {
    /// ARGB kao u Android verziji (0xAARRGGBB).
    init(argb: UInt32) {
        self.init(.sRGB,
                  red: Double((argb >> 16) & 0xFF) / 255,
                  green: Double((argb >> 8) & 0xFF) / 255,
                  blue: Double(argb & 0xFF) / 255,
                  opacity: Double((argb >> 24) & 0xFF) / 255)
    }
}

/// Boje i stil aplikacije (isto kao Ui.java).
enum UI {
    // boje prodavnice (Brand.apply) mogu da zamene osnovne NetPlanet boje
    static var PRIMARY = Color(argb: 0xFF4C4C4E)
    static var PRIMARY_DARK = Color(argb: 0xFF2F2F31)
    static var ACCENT = Color(argb: 0xFFF57921)
    static let OK = Color(argb: 0xFF2E7D32)
    static let ERR = Color(argb: 0xFFD32F2F)
    static let WARN = Color(argb: 0xFFEF6C00)
    static let TEXT = Color(argb: 0xFF2B2B2D)
    static let SUB = Color(argb: 0xFF6E6F71)
    static let BG = Color(argb: 0xFFF4F4F5)
    static let GREY = Color(argb: 0xFF9A9B9D)
    static let LINE = Color(argb: 0xFFE2E2E4)
    static let SOFT = Color(argb: 0xFFFEF0E6)
    static let FIELD = Color(argb: 0xFFF8FAFD)
    static let GREY6E = Color(argb: 0xFF6E6F71)
    static let GREY81 = Color(argb: 0xFF818284)
    static let TAB_BG = Color(argb: 0xFFE4E4E6)

    static var uiPrimary: UIColor { UIColor(PRIMARY) }

    /// Sustina poruke: prvi red, bez tehnickih detalja.
    static func essence(_ msg: String?) -> String {
        guard let msg = msg else { return "" }
        var m = msg.trimmed
        if let nl = m.firstIndex(of: "\n"), nl > m.startIndex { m = String(m[..<nl]).trimmed }
        m = m.replacingRegex("\\s*\\(kod -?\\d+\\)", with: "").replacingRegex("\\s*\\(HTTP \\d+\\)", with: "")
        if m.count > 90 { m = String(m.prefix(87)) + "…" }
        return m
    }

    static func beepOk() { AudioServicesPlaySystemSound(1057) }

    static func beepErr() {
        AudioServicesPlaySystemSound(1073)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

/// Font kao "sans-serif-medium" bold u Android verziji.
extension Font {
    static func ui(_ size: CGFloat, _ bold: Bool = false) -> Font {
        .system(size: size, weight: bold ? .bold : .regular)
    }
}

/// Tekst kao Ui.text().
struct T: View {
    let s: String
    var size: CGFloat
    var color: Color
    var bold = false
    init(_ s: String, _ size: CGFloat, _ color: Color, _ bold: Bool = false) {
        self.s = s; self.size = size; self.color = color; self.bold = bold
    }
    var body: some View { Text(L.t(s)).font(.ui(size, bold)).foregroundColor(color) }
}

/// Mali naslov velikim slovima (Ui.caption).
struct Caption: View {
    let s: String
    init(_ s: String) { self.s = s }
    var body: some View {
        Text(L.t(s).uppercased()).font(.ui(11, true)).kerning(0.9).foregroundColor(UI.SUB)
    }
}

/// Mala oznaka (Ui.chip).
struct Chip: View {
    let s: String
    let bg: Color
    var fg: Color = .white
    var body: some View {
        Text(L.t(s)).font(.ui(12, true)).foregroundColor(fg)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Capsule().fill(bg))
    }
}

/// Ikonica u obojenom krugu (Ui.badgeIcon).
struct BadgeIcon: View {
    let icon: Icon
    let bg: Color
    var fg: Color = .white
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(bg)
            IconView(icon: icon, color: fg).frame(width: size * 0.55, height: size * 0.55)
        }.frame(width: size, height: size)
    }
}

/// Broj u krugu (polja na etiketi, rezultati pretrage).
struct NumBadge: View {
    let n: Int
    let color: Color
    var size: CGFloat = 32
    var font: CGFloat = 15
    var body: some View {
        Text("\(n)").font(.ui(font, true)).foregroundColor(.white)
            .frame(width: size, height: size).background(Circle().fill(color))
    }
}

/// Bela kartica (Ui.card).
struct CardBG: ViewModifier {
    var radius: CGFloat = 18
    var padding: CGFloat = 16
    var elevation: CGFloat = 2
    func body(content: Content) -> some View {
        content.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius).fill(Color.white)
                .shadow(color: .black.opacity(0.13), radius: elevation, x: 0, y: elevation * 0.6))
    }
}

extension View {
    func card(radius: CGFloat = 18, padding: CGFloat = 16, elevation: CGFloat = 2) -> some View {
        modifier(CardBG(radius: radius, padding: padding, elevation: elevation))
    }

    func elevation(_ e: CGFloat) -> some View {
        shadow(color: .black.opacity(e > 0 ? 0.16 : 0), radius: e, x: 0, y: e * 0.6)
    }
}

/// Kartica sa naslovom i obojenom ikonicom (Ui.titledCard). done = zeleni krug sa kvacicom.
struct TitledCard<Content: View>: View {
    let icon: Icon
    let color: Color
    let title: String
    let sub: String
    var done = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                BadgeIcon(icon: done ? .check : icon, bg: done ? UI.OK : color, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    T(title, 17, UI.TEXT, true)
                    if !sub.isEmpty { T(sub, 13, UI.SUB) }
                }
                Spacer(minLength: 0)
            }
            content()
        }.card()
    }
}

/// Gradijent zaglavlje ekrana (Ui.hero).
struct Hero: View {
    let icon: Icon
    let title: String
    let sub: String
    var body: some View {
        HStack(spacing: 14) {
            BadgeIcon(icon: icon, bg: Color.white.opacity(0.2), size: 48)
            VStack(alignment: .leading, spacing: 0) {
                T(title, 20, .white, true)
                if !sub.isEmpty { T(sub, 13, Color.white.opacity(0.87)) }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [UI.PRIMARY, UI.ACCENT], startPoint: .topLeading, endPoint: .bottomTrailing))
            .elevation(3))
    }
}

/// Veliko dugme (Ui.button).
struct PrimaryButton: View {
    let title: String
    let color: Color
    var icon: Icon? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let i = icon { IconView(icon: i, color: .white).frame(width: 22, height: 22) }
                Text(L.t(title)).font(.ui(16, true)).foregroundColor(.white)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 14).fill(color).elevation(3))
            .contentShape(Rectangle())
        }.buttonStyle(PressStyle())
    }
}

/// Obicno dugme sa okvirom (Ui.flat).
struct FlatButton: View {
    let title: String
    var color: Color = UI.PRIMARY
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(L.t(title)).font(.system(size: 15, weight: .medium)).foregroundColor(color)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(UI.LINE, lineWidth: 1))
                .contentShape(Rectangle())
        }.buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Polje za unos (Ui.edit): sivkasta pozadina, narandzast okvir kada je u fokusu.
struct FieldBG: ViewModifier {
    var focused: Bool
    var trailingPad: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .font(.ui(17))
            .foregroundColor(UI.TEXT)
            .tint(UI.ACCENT)
            .padding(.leading, 14).padding(.trailing, trailingPad).padding(.vertical, 12)
            .frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 12).fill(focused ? Color.white : UI.FIELD))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? UI.ACCENT : UI.LINE, lineWidth: focused ? 2 : 1))
    }
}

/// Prazan tekst u polju (hint) u sivoj boji.
func hintText(_ s: String) -> Text { Text(L.t(s)).foregroundColor(UI.GREY) }

/// Tekstualno polje sa sopstvenim fokusom (za dijaloge i podesavanja).
struct EditField: View {
    let hint: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    @FocusState private var f: Bool
    var body: some View {
        Group {
            if secure {
                SecureField("", text: $text, prompt: hintText(hint))
            } else {
                TextField("", text: $text, prompt: hintText(hint))
            }
        }
        .keyboardType(keyboard)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .focused($f)
        .modifier(FieldBG(focused: f))
    }
}

/// Padajuci meni (Spinner) u okviru koji izgleda kao polje za unos (Ui.fieldFrame).
struct Dropdown: View {
    let options: [String]
    @Binding var selection: Int
    var enabled = true
    var centered = false
    var font: Font = .ui(16)
    var framed = true

    var body: some View {
        Menu {
            ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                Button {
                    selection = i
                } label: {
                    if i == selection { Label(L.t(o), systemImage: "checkmark") } else { Text(L.t(o)) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if centered { Spacer(minLength: 0) }
                Text(selection >= 0 && selection < options.count ? L.t(options[selection]) : "")
                    .font(font).foregroundColor(enabled ? UI.TEXT : UI.GREY)
                    .lineLimit(1).multilineTextAlignment(centered ? .center : .leading)
                Spacer(minLength: 0)
                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)).foregroundColor(UI.SUB)
            }
            .padding(.horizontal, framed ? 12 : 4)
            .frame(maxWidth: .infinity, minHeight: framed ? 52 : 46)
            .background(framed ? RoundedRectangle(cornerRadius: 12).fill(UI.FIELD) : nil)
            .overlay(framed ? RoundedRectangle(cornerRadius: 12).stroke(UI.LINE, lineWidth: 1) : nil)
            .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }
}

/// Android CheckBox: narandzasti kvadratic sa kvacicom.
struct CheckBox: View {
    let text: String
    @Binding var on: Bool
    var size: CGFloat = 15
    var body: some View {
        Button { on.toggle() } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(on ? UI.ACCENT : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(on ? UI.ACCENT : UI.SUB, lineWidth: 2))
                    if on { IconView(icon: .check, color: .white).frame(width: 15, height: 15) }
                }
                .frame(width: 18, height: 18)
                .padding(.leading, 5)
                Text(L.t(text)).font(.ui(size)).foregroundColor(UI.TEXT).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
