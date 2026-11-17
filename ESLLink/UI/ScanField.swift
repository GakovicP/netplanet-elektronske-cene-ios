import SwiftUI

/// Selektuje ceo tekst u polju koje je trenutno u fokusu (kao EditText.selectAll()).
func selectAllInFocusedField() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
    }
}

/// Polje za skeniranje: radi sa Bluetooth (keyboard) skenerom, rucnim unosom i kamerom.
struct ScanField<F: Hashable>: View {
    var label: String
    let hint: String
    @Binding var text: String
    var focus: FocusState<F?>.Binding
    let id: F
    let onScan: (String) -> Void
    @EnvironmentObject var app: AppState

    private func fire() {
        let v = text.trimmed
        if v.isEmpty { return }
        onScan(v)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !label.isEmpty { Caption(label).padding(.leading, 2).padding(.bottom, 6) }
            HStack(spacing: 10) {
                TextField("", text: $text, prompt: hintText(hint))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .focused(focus, equals: id)
                    .onSubmit { fire() }
                    .modifier(FieldBG(focused: focus.wrappedValue == id))
                Button {
                    app.startScan { code in
                        text = code
                        fire()
                    }
                } label: {
                    IconView(icon: .scan, color: .white).frame(width: 24, height: 24)
                        .frame(width: 54, height: 52)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [UI.PRIMARY, UI.ACCENT], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .elevation(2))
                }
                .accessibilityLabel("Skeniraj kamerom")
            }
        }
        .onChange(of: focus.wrappedValue) { v in
            if v == id { selectAllInFocusedField() }
        }
    }
}

/// Izbor artikla kada pretraga vrati vise rezultata.
enum ItemPicker {
    static func pick(_ app: AppState, _ q: String, _ res: [Item], _ cb: @escaping (Item) -> Void) {
        if res.count == 1 { cb(res[0]); return }
        if let s = app.session {
            let exact = res.filter { s.isExact($0, q) }
            if exact.count == 1 { cb(exact[0]); return }
        }
        let show = Array(res.prefix(100))
        var spec = DialogSpec(buttons: [DialogButton(title: "Otkaži", kind: .negative)])
        spec.plain = true
        let id = spec.id
        spec.content = AnyView(ItemPickerView(q: q, total: res.count, show: show) { it in
            app.closeDialog(id)
            cb(it)
        })
        app.dialog(spec)
    }
}

struct ItemPickerView: View {
    let q: String
    let total: Int
    let show: [Item]
    let picked: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                T("Izaberi proizvod", 20, UI.TEXT, true)
                T("Pronađeno \(total) za „\(q)”" + (total > 100 ? " (prikazano 100)" : ""), 14, UI.SUB)
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(show.enumerated()), id: \.offset) { i, it in
                        HStack(spacing: 12) {
                                NumBadge(n: i + 1, color: UI.ACCENT, size: 32, font: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    T(it.code, 18, UI.TEXT, true)
                                    T(it.name.isEmpty ? "—" : it.name, 15, UI.SUB).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Chip(s: it.bound ? "Linkovan" : "Slobodan", bg: it.bound ? UI.OK : UI.GREY)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(UI.LINE, lineWidth: 1))
                            .contentShape(Rectangle())
                            .onTapGesture { picked(it) }
                    }
                }.padding(12)
            }
            .frame(maxHeight: min(CGFloat(76 * show.count + 24), UIScreen.main.bounds.height * 0.6))
        }
    }
}

/// Dijalog "Blink by item": izbor boje i trajanja treptanja LED-a etiketa na kojima je artikal.
enum BlinkItem {
    static let durLabels = ["5 sekundi", "10 sekundi", "30 sekundi", "1 minut", "2 minuta", "5 minuta", "10 minuta"]
    static let durSeconds = [5, 10, 30, 60, 120, 300, 600]
    static let defColors: [(String, String)] = [("1", "Crvena"), ("2", "Zelena"), ("3", "Plava"), ("4", "Žuta"),
                                                ("5", "Ljubičasta"), ("6", "Cijan"), ("7", "Bela")]

    final class Model: ObservableObject {
        @Published var color = 0
        @Published var dur = 1
    }

    static func open(_ app: AppState, _ it: Item) {
        guard let s = app.session else { return }
        app.run({ s.ledColors() }, done: { server in show(app, it, server) })
    }

    private static func show(_ app: AppState, _ it: Item, _ server: [(String, String)]) {
        let colors = server.isEmpty ? defColors : server
        let m = Model()
        let last = Prefs.ui.string(forKey: "blinkColor") ?? "2"
        m.color = colors.firstIndex { $0.0 == last } ?? 0
        let d = Prefs.ui.object(forKey: "blinkDur") as? Int ?? 1
        m.dur = min(durLabels.count - 1, max(0, d))
        let content = BlinkView(m: m, text: it.code + (it.name.isEmpty ? "" : "\n" + it.name), colors: colors.map { $0.1 })
        app.dialog(DialogSpec(title: "Blink by item", content: AnyView(content), buttons: [
            DialogButton(title: "Otkaži", kind: .negative),
            DialogButton(title: "Blink", kind: .positive, action: {
                guard let s = app.session else { return }
                let c = colors[max(0, min(colors.count - 1, m.color))]
                let di = max(0, min(durLabels.count - 1, m.dur))
                Prefs.ui.set(c.0, forKey: "blinkColor")
                Prefs.ui.set(di, forKey: "blinkDur")
                let color = Int(c.0) ?? 2
                let cycles = durSeconds[di] * 1000 / 400
                app.run({ try s.ledForItem(it.id, color: color, cycles: cycles) },
                        done: { _ in app.showToast("Blink poslat: " + c.1 + ", " + durLabels[di]) })
            }),
        ]))
    }
}

private struct BlinkView: View {
    @ObservedObject var m: BlinkItem.Model
    let text: String
    let colors: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            T(text, 14, UI.SUB).padding(.top, 4)
            T("Boja", 13, UI.SUB, true).padding(.top, 14).padding(.bottom, 6)
            Dropdown(options: colors, selection: $m.color)
            T("Trajanje", 13, UI.SUB, true).padding(.top, 14).padding(.bottom, 6)
            Dropdown(options: BlinkItem.durLabels, selection: $m.dur)
        }
        .padding(.horizontal, 24).padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
