import SwiftUI

struct UnlinkView: View {
    let prefill: String
    @EnvironmentObject var app: AppState
    @State private var eslText = ""
    @FocusState private var focus: Int?
    @State private var split: (Tag, Int)?
    @State private var started = false

    private var S: Session { app.session! }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TitledCard(icon: .linkOff, color: UI.ERR, title: "Unlink", sub: "Skeniraj etiketu koju odvezuješ") {
                    ScanField(label: "Barkod etikete", hint: "Skeniraj ili ukucaj ESL", text: $eslText, focus: $focus, id: 1) { onEsl($0) }
                        .padding(.top, 14)
                }
                if let sp = split {
                    splitView(sp.0, sp.1).padding(.top, 12)
                }
            }.padding(14)
        }
        .scrollDismissesKeyboard(.interactively)
        .chrome("Unlink")
        .onAppear {
            if started { return }
            started = true
            if !prefill.isEmpty {
                eslText = prefill
                onEsl(prefill)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focus = 1 }
            }
        }
    }

    private func error(_ m: String) { UI.beepErr(); app.status(m, UI.ERR) }

    private func refocus() {
        focus = nil
        DispatchQueue.main.async { focus = 1 }
    }

    private func onEsl(_ raw: String) {
        let code = eslCode(raw)
        if code != raw.trimmed { eslText = code }
        split = nil
        let s = S
        app.run({ () -> (Tag?, Int) in
            guard let t = try s.getTag(code) else { return (nil, -1) }
            return (t, s.strategyType(t))
        }, done: { r in
            guard let t = r.0 else {
                error("Skenirana etiketa ne postoji")
                eslText = ""
                refocus()
                return
            }
            let type = r.1
            if t.bindings.isEmpty {
                app.status("ESL " + t.code + " nema linkovanih artikala", UI.WARN)
                UI.beepErr()
                eslText = ""
                refocus()
                return
            }
            let normal = type == 0 || (type < 0 && t.bindings.count <= 1)
            if normal { unlinkAll(t) } else { split = (t, type) }
        })
    }

    private func unlinkAll(_ t: Tag) {
        let s = S
        app.run({ try s.unlinkAll(t) }, done: { _ in
            UI.beepOk()
            app.status("Unlink uspešan ✓\nESL " + t.code + (t.goodsSummary().isEmpty ? "" : "\n" + t.goodsSummary()), UI.OK)
            split = nil
            eslText = ""
            refocus()
        }, fail: { e in error("Unlink nije uspeo: " + errMsg(e)) })
    }

    private func splitView(_ t: Tag, _ type: Int) -> some View {
        var strat = type == 2 ? "Self adapt" : "Split-screen"
        if !t.strategyName.isEmpty { strat = t.strategyName }
        return VStack(spacing: 14) {
            TitledCard(icon: .tag, color: UI.GREY6E, title: "ESL " + t.code,
                       sub: strat + (t.layoutName.isEmpty ? "" : " • " + t.layoutName) + " • \(t.bindings.count) art.") {
                VStack(spacing: 10) {
                    ForEach(Array(t.bindings.enumerated()), id: \.offset) { i, bd in
                        HStack(spacing: 12) {
                            NumBadge(n: i + 1, color: UI.GREY6E)
                            VStack(alignment: .leading, spacing: 0) {
                                T(bd.itemCode, 18, UI.TEXT, true)
                                if !bd.itemName.isEmpty { T(bd.itemName, 14, UI.SUB) }
                            }
                            Spacer(minLength: 0)
                            Button { removeOne(t, bd) } label: {
                                BadgeIcon(icon: .linkOff, bg: UI.ERR, size: 48).elevation(2)
                            }.accessibilityLabel("Unlink")
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(UI.CARD))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(UI.LINE, lineWidth: 1))
                    }
                }.padding(.top, 10)
            }
            PrimaryButton(title: "Unlink all", color: UI.ERR, icon: .linkOff) {
                app.confirm("Odvezati sve artikle sa ESL " + t.code + "?", "Unlink all") { unlinkAll(t) }
            }
        }
    }

    private func removeOne(_ t: Tag, _ bd: TagBinding) {
        let s = S
        app.run({ () -> (Tag?, Int) in
            try s.removeBinding(t, bd)
            let fresh = try s.getTag(t.code)
            return (fresh, fresh == nil ? -1 : s.strategyType(fresh!))
        }, done: { r in
            UI.beepOk()
            app.status(L.t("Odvezan ") + bd.itemCode + L.t(" sa ESL ") + t.code, UI.OK)
            if let fresh = r.0, !fresh.bindings.isEmpty {
                split = (fresh, r.1)
            } else {
                split = nil
                eslText = ""
                refocus()
            }
        }, fail: { e in error("Unlink nije uspeo: " + errMsg(e)) })
    }
}
