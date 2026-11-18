import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var account = ""
    @State private var password = ""
    @State private var remember = false
    @State private var shown = false
    @State private var serverInfo = L.t("Automatski")
    @FocusState private var focus: Int?

    private let store = ServerStore()
    /// Nalog, lozinka i "zapamti me" (globalno, kao SharedPreferences "login" na Androidu).
    private static let lp = UserDefaults(suiteName: "login") ?? .standard
    private var version: String {
        "Verzija " + ((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // gornji red: levo dugme za servere, desno izbor jezika
                HStack {
                    Button { app.open(.servers) } label: {
                        HStack(spacing: 6) {
                            IconView(icon: .server, color: UI.PRIMARY).frame(width: 22, height: 22)
                            Text(serverInfo).font(.ui(14, true)).foregroundColor(UI.TEXT).lineLimit(1)
                                .frame(maxWidth: 150, alignment: .leading).fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Color.white).elevation(4))
                    }.buttonStyle(PressStyle()).accessibilityLabel(L.t("Serveri"))
                    Spacer()
                    Menu {
                        ForEach(L.LANGS, id: \.code) { lg in
                            Button { app.setLang(lg.code) } label: {
                                if lg.code == L.lang { Label(lg.flag + "  " + lg.name, systemImage: "checkmark") } else { Text(lg.flag + "  " + lg.name) }
                            }
                        }
                    } label: {
                        Text(L.current.flag + " " + L.current.code.uppercased()).font(.ui(14, true)).foregroundColor(UI.TEXT)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(Color.white).elevation(4))
                    }.accessibilityLabel(L.t("Jezik"))
                }

                VStack(spacing: 0) {
                    ZStack {
                        Circle().fill(Color.white).elevation(6)
                        BrandLogo(size: 62)
                    }.frame(width: 92, height: 92)
                    T("Elektronske cene", 30, .white, true).padding(.top, 10)
                    Text("by NetPlanet").font(.ui(15)).kerning(2.2).foregroundColor(Color.white.opacity(0.8))
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 0) {
                    T("Prijava", 22, UI.TEXT, true)
                    T("Unesi svoje podatke", 14, UI.SUB)
                    Caption("Korisnički nalog").padding(.top, 16)
                    TextField("", text: $account, prompt: hintText("korisnik@firma.rs"))
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focus, equals: 1)
                        .submitLabel(.next)
                        .onSubmit { focus = 2 }
                        .modifier(FieldBG(focused: focus == 1))
                        .padding(.top, 6)
                    Caption("Lozinka").padding(.top, 14)
                    ZStack(alignment: .trailing) {
                        Group {
                            if shown {
                                TextField("", text: $password, prompt: hintText("••••••••"))
                            } else {
                                SecureField("", text: $password, prompt: hintText("••••••••"))
                            }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focus, equals: 2)
                        .submitLabel(.go)
                        .onSubmit { doLogin() }
                        .modifier(FieldBG(focused: focus == 2, trailingPad: 52))
                        Button {
                            shown.toggle()
                            focus = 2
                        } label: {
                            IconView(icon: shown ? .eye : .eyeOff, color: shown ? UI.PRIMARY : UI.SUB)
                                .frame(width: 24, height: 24).frame(width: 48, height: 48)
                        }.accessibilityLabel(L.t("Prikaži šifru"))
                    }
                    .padding(.top, 6)
                    CheckBox(text: "Zapamti me", on: $remember).padding(.top, 8)
                    PrimaryButton(title: "Prijavi se", color: UI.PRIMARY) { doLogin() }.padding(.top, 14)
                }
                .padding(.horizontal, 20).padding(.vertical, 22)
                .card(radius: 18, padding: 0, elevation: 8)
                .padding(.top, 24)

                NetPlanetFooter(onDark: true).padding(.top, 22)
                    .contentShape(Rectangle())
                    .onTapGesture { app.showSupport() } // podrska: dodir na NetPlanet logo u dnu
                    .accessibilityLabel(L.t("Podrška"))
                T(version, 12, Color.white.opacity(0.67)).padding(.top, 14)
                Button { app.showPrivacy() } label: {
                    Text(L.t("Politika privatnosti")).font(.ui(12)).underline().foregroundColor(Color.white.opacity(0.67))
                        .padding(.vertical, 6)
                }.buttonStyle(.plain).padding(.top, 4)
            }
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 22)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(LinearGradient(colors: [UI.PRIMARY_DARK, UI.PRIMARY, UI.ACCENT], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { reload() }
    }

    private func reload() {
        let p = LoginView.lp
        var acc = p.string(forKey: "account")
        var pass = ""
        var rem = p.bool(forKey: "remember")
        if acc == nil { // prelaz sa starije verzije: poslednji server
            let last = store.get(store.lastId())
            acc = last?.lastAccount ?? ""
            rem = last?.remember ?? false
            pass = rem ? (last?.savedPass ?? "") : ""
        } else if rem {
            pass = Data(base64Encoded: p.string(forKey: "pass") ?? "").flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
        if account.isEmpty { account = acc ?? "" }
        if password.isEmpty { password = pass }
        remember = rem
        if let pd = app.pendingServer { serverInfo = pd.shortName() }
        else if let fx = store.fixed() { serverInfo = fx.shortName() }
        else { serverInfo = L.t("Automatski") }
    }

    /// Uspesna prijava na jednom serveru.
    private struct Hit {
        let srv: Server
        let api: Api
        let data: J

        /// Naziv za izbor servera: naziv iz liste, inace prodavnica iz odgovora servera (bez IP adrese).
        var label: String {
            let n = srv.name.trimmed
            let st = Json.s(data, "storeName").trimmed
            if !n.isEmpty && !st.isEmpty && n.lowercased() != st.lowercased() { return n + " – " + st }
            if !n.isEmpty { return n }
            if !st.isEmpty { return st }
            let u = Json.s(data, "userName").trimmed
            return u.isEmpty ? srv.shortName() : u
        }
    }

    /// " (server Naziv)" samo kad server ima naziv – IP adrese se ne prikazuju.
    private static func onServer(_ s: Server) -> String {
        s.name.trimmed.isEmpty ? "" : " (server " + s.name.trimmed + ")"
    }

    private final class Scan {
        var hits: [Hit] = []
        var unreachable = 0
        var authErr: String?
        var wrongPass: Server?
        var locked: Server?
        var session: Session?
        var stop: Bool { !hits.isEmpty || wrongPass != nil || locked != nil }
    }

    // ---- zastita od zakljucavanja naloga (server: 3 pogresne lozinke -> zakljucan 300 s)
    private static let lockSec: Double = 300
    private static let guardPrefs = UserDefaults(suiteName: "loginguard") ?? .standard
    private static func guardKey(_ acc: String) -> String { acc.lowercased() }

    private static func mmss(_ s: Double) -> String {
        let sec = Int(s.rounded(.up))
        return String(format: "%d:%02d", sec / 60, sec % 60)
    }

    private func doLogin() {
        let acc = account.trimmed
        let pass = password
        if acc.isEmpty || pass.isEmpty { app.showError("Unesi nalog i lozinku."); return }
        focus = nil
        let g = LoginView.guardPrefs
        let key = LoginView.guardKey(acc)
        let now = Date().timeIntervalSince1970
        let until = g.double(forKey: key + ":until")
        if now < until {
            app.showError("Zbog zaštite naloga sledeći pokušaj za " + LoginView.mmss(until - now) + ".")
            return
        }
        var fails = g.integer(forKey: key + ":fails")
        if fails > 0 && now - g.double(forKey: key + ":last") > LoginView.lockSec {
            fails = 0
            g.removeObject(forKey: key + ":fails")
        }
        if fails == 1 {
            app.dialog(DialogSpec(title: "Proveri lozinku",
                                  message: "Prethodna lozinka za " + acc + " je bila pogrešna. Server zaključava nalog na svim uređajima posle 3 pogrešne lozinke.\n\nPošalji ovu lozinku?",
                                  buttons: [
                                      DialogButton(title: "Otkaži", kind: .negative),
                                      DialogButton(title: "Pošalji", kind: .positive, action: { go(acc, pass) }),
                                  ]))
            return
        }
        go(acc, pass)
    }

    private func lastUrl(_ acc: String) -> String {
        let u = LoginView.lp.string(forKey: "server:" + acc.lowercased()) ?? ""
        if u.isEmpty, let x = store.verified().first(where: { $0.lastAccount.lowercased() == acc.lowercased() }) {
            return Server.norm(x.url)
        }
        return u
    }

    private static func same(_ a: Server, _ b: Server) -> Bool {
        Server.norm(a.url).lowercased() == Server.norm(b.url).lowercased()
    }

    /// Prijava na servere paralelno (kratki timeout); rezultat ide u sc.
    private static func tryLogin(_ cands: [Server], _ acc: String, _ pass: String, _ sc: Scan) {
        if cands.isEmpty { return }
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: cands.count) { i in
            let srv = cands[i]
            let api = Api(srv)
            api.timeout = 8
            do {
                let d = try api.login(acc, pass)
                api.timeout = 45
                lock.lock(); sc.hits.append(Hit(srv: srv, api: api, data: d)); lock.unlock()
            } catch AppError.api(let m) {
                let l = m.lowercased()
                lock.lock()
                if l.contains("exceeds the limit") { sc.locked = srv }
                else if l.contains("password error") { sc.wrongPass = srv }
                else if sc.authErr == nil { sc.authErr = m }
                lock.unlock()
            } catch {
                lock.lock(); sc.unreachable += 1; lock.unlock()
            }
        }
    }

    /// Ceo login u jednom poslu (jedan loading): nalog upisan u listi -> pravo na taj server;
    /// inace poslednji server ovog naloga, pa svi paralelno; novi serveri iz osvezene liste na kraju.
    /// Ako server kaze "pogresna lozinka" ili "zakljucan", dalje se ne proba.
    private func go(_ acc: String, _ pass: String) {
        let key = LoginView.guardKey(acc)
        let last = lastUrl(acc)
        let pend = app.pendingServer
        let fixed = pend ?? store.fixed()
        let store = self.store
        app.run({ () -> Scan in
            let sc = Scan()
            // lista sa interneta se preuzima paralelno sa prijavom
            let listSem = DispatchSemaphore(value: 0)
            var fresh: ServerList.Result?
            DispatchQueue.global(qos: .userInitiated).async { fresh = ServerList.load(); listSem.signal() }
            func finish() throws -> Scan {
                if sc.hits.count == 1 {
                    let h = sc.hits[0]
                    let s = Session(h.api, h.srv, h.data)
                    try s.loadScenarios()
                    sc.session = s
                }
                return sc
            }
            if let f = fixed {
                LoginView.tryLogin([f], acc, pass, sc)
                return try finish()
            }
            // 1) nalog upisan u listi ("accounts")
            var list = ServerList.merge(ServerList.cached())
            var direct = ServerList.candidates(store, list, nil, acc)
            let usesAccounts = ServerList.cachedAt() == 0 || list.contains { !$0.accounts.isEmpty }
            if direct.isEmpty && usesAccounts {
                if listSem.wait(timeout: .now() + 6) == .success, let r = fresh {
                    listSem.signal()
                    list = r.entries
                    direct = ServerList.candidates(store, list, nil, acc)
                }
            }
            var done: [Server] = []
            if !direct.isEmpty {
                LoginView.tryLogin(direct, acc, pass, sc)
                if sc.stop { return try finish() }
                done += direct
            }
            // 2) poslednji server ovog naloga, pa svi
            let all = ServerList.all(store, list, pend)
            if !last.isEmpty && all.count > 1,
               let first = all.first(where: { x in Server.norm(x.url).lowercased() == last.lowercased() && !done.contains(where: { d in LoginView.same(d, x) }) }) {
                LoginView.tryLogin([first], acc, pass, sc)
                done.append(first)
                if sc.stop { return try finish() }
            }
            let rest = all.filter { s in !done.contains { LoginView.same($0, s) } }
            LoginView.tryLogin(rest, acc, pass, sc)
            done += rest
            if !sc.stop {
                // nalog nije nadjen: mozda je na serveru koji je tek dodat u listu
                if listSem.wait(timeout: .now() + 10) == .success, let r = fresh {
                    listSem.signal()
                    let more = ServerList.all(store, r.entries, pend).filter { s in !done.contains { LoginView.same($0, s) } }
                    LoginView.tryLogin(more, acc, pass, sc)
                }
            }
            return try finish()
        }, done: { sc in
            let g = LoginView.guardPrefs
            let now = Date().timeIntervalSince1970
            if sc.hits.isEmpty {
                if let l = sc.locked {
                    g.set(now + LoginView.lockSec, forKey: key + ":until")
                    g.removeObject(forKey: key + ":fails")
                    app.showError("Nalog je zaključan" + LoginView.onServer(l) + " zbog previše pogrešnih lozinki (na svim uređajima). Pokušaj ponovo za 5 minuta.")
                    return
                }
                if let w = sc.wrongPass {
                    let f = g.integer(forKey: key + ":fails") + 1
                    g.set(f, forKey: key + ":fails")
                    g.set(now, forKey: key + ":last")
                    if f >= 2 {
                        g.set(now + LoginView.lockSec, forKey: key + ":until")
                        g.removeObject(forKey: key + ":fails")
                        app.showError("Pogrešna lozinka po drugi put" + LoginView.onServer(w) + ". Da se nalog ne bi zaključao, sledeći pokušaj za 5 minuta.")
                    } else {
                        app.showError("Pogrešna lozinka" + LoginView.onServer(w) + ". Još jedna greška može da zaključa nalog.")
                    }
                    return
                }
                var m: String
                if let f = fixed {
                    m = sc.authErr.map { "Prijava na " + f.shortName() + " nije uspela: " + $0 }
                        ?? "Server " + f.shortName() + " nije dostupan. Proveri internet ili izaberi automatski izbor."
                } else if let a = sc.authErr {
                    m = "Nalog nije pronađen ni na jednom serveru: " + a
                    if sc.unreachable > 0 { m += " (\(sc.unreachable) server(a) nedostupno)" }
                } else { m = "Nijedan server nije dostupan. Proveri internet." }
                app.showError(m)
                return
            }
            for k in [":fails", ":until", ":last"] { g.removeObject(forKey: key + k) }
            if let s = sc.session { complete(s, sc.hits[0].srv, acc, pass); return }
            let hits = sc.hits.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
            let m = ChoiceModel()
            m.sel = hits.firstIndex { Server.norm($0.srv.url).lowercased() == last.lowercased() } ?? 0
            var spec = DialogSpec(title: "Nalog postoji na više servera",
                                  content: AnyView(ChoiceList(m: m, names: hits.map { $0.label })), buttons: [
                DialogButton(title: "Otkaži", kind: .negative, action: { logoutOthers(hits, nil) }),
                DialogButton(title: "Prijavi se", kind: .positive, action: {
                    finishLogin(hits[max(0, min(hits.count - 1, m.sel))], hits, acc, pass)
                }),
            ])
            spec.cancelable = false
            app.dialog(spec)
        })
    }

    private func logoutOthers(_ hits: [Hit], _ keep: Hit?) {
        let others = hits.filter { $0.api !== keep?.api }
        DispatchQueue.global().async { for h in others { h.api.logout() } }
    }

    private func finishLogin(_ h: Hit, _ all: [Hit], _ acc: String, _ pass: String) {
        logoutOthers(all, h)
        app.run({ () -> Session in
            let s = Session(h.api, h.srv, h.data)
            try s.loadScenarios()
            return s
        }, done: { s in complete(s, h.srv, acc, pass) })
    }

    private func complete(_ s: Session, _ srv: Server, _ acc: String, _ pass: String) {
        let rem = remember
        srv.verified = true
        srv.lastAccount = acc
        srv.remember = rem
        srv.savedPass = rem ? pass : ""
        store.save(srv)
        store.setLast(srv.id)
        let p = LoginView.lp
        p.set(acc, forKey: "account")
        p.set(rem, forKey: "remember")
        p.set(rem ? Data(pass.utf8).base64EncodedString() : "", forKey: "pass")
        p.set(Server.norm(srv.url), forKey: "server:" + acc.lowercased())
        if let pd = app.pendingServer, Server.norm(pd.url).lowercased() == Server.norm(srv.url).lowercased() {
            app.pendingServer = nil
            store.setMode(srv.id)
        }
        app.brandAfterLogin(acc) // logo i boje prodavnice (logo se preuzima u pozadini)
        app.loggedIn(s)
    }
}

/// Izbor jedne stavke (radio lista) u dijalogu.
final class ChoiceModel: ObservableObject {
    @Published var sel = 0
}

struct ChoiceList: View {
    @ObservedObject var m: ChoiceModel
    let names: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(names.enumerated()), id: \.offset) { i, n in
                Button { m.sel = i } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().stroke(m.sel == i ? UI.ACCENT : UI.GREY, lineWidth: 2).frame(width: 20, height: 20)
                            if m.sel == i { Circle().fill(UI.ACCENT).frame(width: 10, height: 10) }
                        }
                        T(n, 16, UI.TEXT)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24).padding(.top, 4)
    }
}
