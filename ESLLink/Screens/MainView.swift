import SwiftUI

struct MainView: View {
    @EnvironmentObject var app: AppState
    @State private var refresh = 0

    private struct TileDef { let title: String, sub: String, icon: Icon, color: Color, target: Screen? }
    private let tiles: [TileDef] = [
        TileDef(title: "Link", sub: "Link i Multilink", icon: .link, color: UI.ACCENT, target: .link),
        TileDef(title: "Unlink", sub: "Odvezivanje etiketa", icon: .linkOff, color: UI.PRIMARY, target: .unlink("")),
        TileDef(title: "Item List", sub: "Pregled artikala", icon: .cart, color: Color(argb: 0xFFF57921), target: .items),
        TileDef(title: "ESL List", sub: "Pregled etiketa", icon: .tag, color: Color(argb: 0xFF6E6F71), target: .esls),
        TileDef(title: "APs", sub: "Bazne stanice", icon: .wifi, color: Color(argb: 0xFF818284), target: .aps),
        TileDef(title: "Monitoring", sub: "Stanje sistema", icon: .chart, color: Color(argb: 0xFFF57921), target: .monitoring),
        TileDef(title: "Odjava", sub: "Kraj rada", icon: .logout, color: Color(argb: 0xFF9A9B9D), target: nil),
    ]

    var body: some View {
        let s = app.session
        let _ = refresh
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            T("Dobrodošli", 14, Color.white.opacity(0.8))
                            T(s.map { $0.userName.isEmpty ? $0.loginId : $0.userName } ?? "", 22, .white, true)
                        }
                        Spacer(minLength: 0)
                        ZStack {
                            Circle().fill(Color.white)
                            BrandLogo(size: 36)
                        }.frame(width: 52, height: 52)
                        .contentShape(Circle())
                        .onTapGesture { app.showSupport() }
                        .accessibilityLabel("Podrška")
                    }
                    Text(L.t(header(s))).font(.ui(13)).foregroundColor(Color.white.opacity(0.9)).lineSpacing(3).padding(.top, 10)
                    HStack(spacing: 8) {
                        Chip(s: "Scenario: " + (s?.scenarioName ?? ""), bg: Color.white.opacity(0.2))
                        if (s?.stores.count ?? 0) > 1 {
                            Button { chooseStore() } label: { Chip(s: "Promeni prodavnicu ▾", bg: .white, fg: UI.PRIMARY) }
                        }
                    }.padding(.top, 10)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [UI.PRIMARY, UI.ACCENT], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .elevation(4))

                ForEach(0..<((tiles.count + 1) / 2), id: \.self) { r in
                    let a = tiles[r * 2]
                    if r * 2 + 1 < tiles.count {
                        HStack(spacing: 12) {
                            tile(a, centered: false)
                            tile(tiles[r * 2 + 1], centered: false)
                        }
                    } else {
                        // poslednja plocica (Odjava) sama u redu – centrirana
                        HStack {
                            Spacer(minLength: 0)
                            tile(a, centered: true).frame(width: (UIScreen.main.bounds.width - 32 - 12) / 2 + 6)
                            Spacer(minLength: 0)
                        }
                    }
                }
                NetPlanetFooter().padding(.top, 12)
            }.padding(16)
        }
        .chrome("Elektronske cene", back: false, menu: mainMenu(s))
    }

    private func header(_ s: Session?) -> String {
        guard let s = s else { return "" }
        var h = "Prodavnica: " + s.storeName + (s.server.name.trimmed.isEmpty ? "" : "\nServer: " + s.server.name.trimmed)
        if !s.warning.isEmpty { h += "\n⚠ " + s.warning }
        return h
    }

    private func tile(_ t: TileDef, centered: Bool) -> some View {
        Button {
            if let target = t.target { app.open(target) } else { askLogout() }
        } label: {
            VStack(alignment: centered ? .center : .leading, spacing: 0) {
                BadgeIcon(icon: t.icon, bg: t.color, size: 46)
                T(t.title, 17, UI.TEXT, true).padding(.top, 12)
                T(t.sub, 13, UI.SUB)
            }
            .padding(.horizontal, 16).padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white).elevation(2))
            .contentShape(Rectangle())
        }.buttonStyle(PressStyle())
    }

    private func mainMenu(_ s: Session?) -> [(String, () -> Void)] {
        var m: [(String, () -> Void)] = []
        if (s?.stores.count ?? 0) > 1 { m.append(("Promeni prodavnicu", { chooseStore() })) }
        m.append(("Dnevnik komunikacije", { app.showLog = true }))
        m.append(("Odjava", { askLogout() }))
        return m
    }

    /// Izbor prodavnice kada nalog ima podprodavnice.
    private func chooseStore() {
        guard let s = app.session, s.stores.count > 1 else { app.showToast("Nalog nema drugih prodavnica"); return }
        var spec = DialogSpec(title: "Izaberi prodavnicu", buttons: [DialogButton(title: "Otkaži", kind: .negative)])
        let id = spec.id
        spec.content = AnyView(DialogScroll {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(s.stores.enumerated()), id: \.offset) { _, st in
                    storeRow(s, st, id)
                }
            }.padding(.top, 8)
        })
        app.dialog(spec)
    }

    private func storeRow(_ s: Session, _ st: (id: String, name: String, depth: Int), _ id: UUID) -> some View {
        let on: Bool = st.id == s.storeId
        let pad: String = String(repeating: "    ", count: st.depth) + (st.depth > 0 ? "└ " : "")
        let label: String = pad + (st.name.isEmpty ? st.id : st.name)
        return Button {
            app.closeDialog(id)
            if on { return }
            app.run({ try s.switchStore(st.id, st.name) }, done: { _ in
                UI.beepOk()
                app.showToast("Prodavnica: " + s.storeName)
                refresh += 1
            })
        } label: {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(on ? UI.ACCENT : UI.SUB, lineWidth: 2).frame(width: 20, height: 20)
                    if on { Circle().fill(UI.ACCENT).frame(width: 10, height: 10) }
                }
                Text(L.t(label)).font(.ui(16)).foregroundColor(UI.TEXT)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24).frame(minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func askLogout() {
        app.confirm("Odjaviti se?", "Odjava") { logout() }
    }

    private func logout() {
        let s = app.session
        app.run({ s?.api.logout() }, done: { _ in app.loggedOut() }, fail: { _ in app.loggedOut() })
    }
}
