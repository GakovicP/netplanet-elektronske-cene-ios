import SwiftUI

/// Unos i izmena adresa servera.
struct ServersView: View {
    @EnvironmentObject var app: AppState
    @State private var servers: [Server] = []
    private let store = ServerStore()

    @State private var mode = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                T("Server za prijavu", 16, UI.TEXT, true)
                T("Dodirni za izbor. Dugi pritisak na ručno uneti server menja ili briše server.", 13, UI.SUB).padding(.top, 4)
                VStack(spacing: 10) {
                    Button { choose(nil) } label: {
                        TitledCard(icon: .search, color: mode.isEmpty ? UI.ACCENT : UI.GREY,
                                   title: (mode.isEmpty ? "✓ " : "") + "Automatski izbor",
                                   sub: "Aplikacija sama pronalazi server na kom postoji nalog.") { EmptyView() }
                            .multilineTextAlignment(.leading)
                    }.buttonStyle(PressStyle())
                    ForEach(servers, id: \.id) { s in
                        let on = s.id == mode
                        TitledCard(icon: .server, color: on ? UI.ACCENT : UI.PRIMARY,
                                   title: (on ? "✓ " : "") + (s.name.isEmpty ? s.url : s.name),
                                   sub: (s.name.isEmpty ? "" : s.url + (s.lastAccount.isEmpty ? "" : "\n"))
                                       + (s.lastAccount.isEmpty ? "" : "Nalog: " + s.lastAccount)) { EmptyView() }
                            .multilineTextAlignment(.leading)
                            .contentShape(Rectangle())
                            .onTapGesture { choose(s) }
                            .onLongPressGesture { edit(s) }
                    }
                }.padding(.top, 8)
                PrimaryButton(title: "Dodaj server ručno", color: UI.PRIMARY, icon: .server) { edit(nil) }.padding(.top, 14)
            }.padding(16)
        }
        .chrome("Serveri", menu: [])
        .onAppear { render() }
    }

    private func render() {
        servers = store.verified()
        mode = store.mode()
        if !mode.isEmpty && store.get(mode) == nil { store.setMode(""); mode = "" }
    }

    private func choose(_ s: Server?) {
        store.setMode(s?.id ?? "")
        app.pendingServer = nil
        app.showToast(s.map { "Prijava ide na " + $0.shortName() } ?? "Automatski izbor servera")
        app.back()
    }

    private func edit(_ orig: Server?) {
        var spec = DialogSpec(buttons: [])
        let id = spec.id
        spec.content = AnyView(ServerEditor(orig: orig, close: { app.closeDialog(id) }, saved: { s in
            commit(s, orig, id)
        }, deleted: { render() }))
        app.dialog(spec)
    }

    private func commit(_ s: Server, _ orig: Server?, _ dlg: UUID) {
        if orig == nil {
            // cuva se tek kada prijava uspe
            app.pendingServer = s
            app.closeDialog(dlg)
            app.back()
        } else {
            store.save(s)
            if let cur = app.session, cur.server.id == s.id { app.showToast("Izmene važe od sledeće prijave") }
            app.closeDialog(dlg)
            render()
        }
    }
}

/// Dijalog za novi server / izmenu servera.
struct ServerEditor: View {
    let orig: Server?
    let close: () -> Void
    let saved: (Server) -> Void
    let deleted: () -> Void
    @EnvironmentObject var app: AppState

    @State private var scheme = 0
    @State private var url = ""
    @State private var port = ""
    @State private var name = ""
    @State private var adv = false
    @State private var tUrl = "", tUser = "", tPass = "", bp = "", up = ""
    @State private var md5 = false, trust = false
    @State private var urlErr = false
    @State private var loaded = false

    private func label(_ s: String) -> some View { T(s, 13, UI.SUB, true).padding(.top, 10).padding(.bottom, 4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(orig == nil ? "Novi server" : "Izmena servera").font(.system(size: 20, weight: .semibold)).foregroundColor(UI.TEXT)
                .padding(.horizontal, 24).padding(.top, 22)
            DialogScroll {
                VStack(alignment: .leading, spacing: 0) {
                    label("Protokol")
                    Dropdown(options: ["http", "https"], selection: $scheme)
                    label("Adresa servera *")
                    EditField(hint: "npr. 192.168.1.10 ili esl.firma.rs", text: $url, keyboard: .URL)
                    if urlErr { T("Unesi adresu", 12, UI.ERR).padding(.top, 4) }
                    label("Port")
                    EditField(hint: "8085", text: $port, keyboard: .numberPad)
                    label("Naziv (opciono)")
                    EditField(hint: "npr. Prodavnica 1", text: $name)

                    Button { adv.toggle() } label: {
                        T((adv ? "▾" : "▸") + " Napredno (link servis / SSL)", 15, UI.PRIMARY, true)
                    }.padding(.top, 16)
                    if adv {
                        label("Adresa link servisa (third API)")
                        EditField(hint: "prazno = isti host:port kao server", text: $tUrl, keyboard: .URL)
                        label("Link servis – korisnik")
                        EditField(hint: "prazno = isti nalog kao za prijavu", text: $tUser)
                        label("Link servis – lozinka")
                        EditField(hint: "prazno = ista lozinka kao za prijavu", text: $tPass, secure: true)
                        CheckBox(text: "Šalji lozinku link servisu kao MD5", on: $md5)
                        label("Putanja za link")
                        EditField(hint: "third/bind/v1/bind", text: $bp)
                        label("Putanja za unlink")
                        EditField(hint: "third/bind/v1/unBind", text: $up)
                        CheckBox(text: "Prihvati sve SSL sertifikate (self-signed)", on: $trust)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
            }
            HStack(spacing: 4) {
                if let o = orig {
                    btn("Obriši") {
                        close()
                        app.confirm("Obrisati server \(o.display())?", "Obriši") {
                            ServerStore().delete(o.id)
                            deleted()
                        }
                    }
                }
                Spacer(minLength: 0)
                btn("Otkaži") { close() }
                btn(orig == nil ? "Koristi za prijavu" : "Sačuvaj") { save() }
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }
        .onAppear {
            if loaded { return }
            loaded = true
            let s = orig ?? Server()
            let p = s.parts()
            scheme = p.0 == "https" ? 1 : 0
            url = p.1; port = p.2; name = s.name
            tUrl = s.thirdUrl; tUser = s.thirdUser; tPass = s.thirdPass; md5 = s.thirdMd5
            bp = s.bindPath; up = s.unbindPath; trust = s.trustAll
        }
    }

    private func btn(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t.uppercased()).font(.system(size: 14, weight: .semibold)).kerning(0.6)
                .foregroundColor(UI.ACCENT).padding(.horizontal, 8).frame(minHeight: 40)
        }
    }

    private func save() {
        let u = url.trimmed
        if u.isEmpty { urlErr = true; return }
        urlErr = false
        let s = orig?.copy() ?? Server()
        s.url = Server.build(scheme == 1 ? "https" : "http", u, port)
        s.name = name.trimmed
        s.thirdUrl = tUrl.trimmed
        s.thirdUser = tUser.trimmed
        s.thirdPass = tPass
        s.thirdMd5 = md5
        s.bindPath = bp.trimmed
        s.unbindPath = up.trimmed
        s.trustAll = trust
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        app.run({ try Api(s).ping() }, done: { _ in
            app.showToast("Server je dostupan ✓")
            saved(s)
        }, fail: { e in
            UI.beepErr()
            app.dialog(DialogSpec(title: "Server nije dostupan", message: s.url + "\n\n" + errMsg(e), buttons: [
                DialogButton(title: "Sačuvaj ipak", kind: .neutral, action: { saved(s) }),
                DialogButton(title: "Ispravi", kind: .positive),
            ]))
        })
    }
}
