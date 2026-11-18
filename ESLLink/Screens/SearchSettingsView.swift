import SwiftUI

/// Podesavanja: polja za pretragu proizvoda, izbor scenarija i skener kamere.
struct SearchSettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var code = true
    @State private var name = true
    @State private var qr = false
    @State private var engine = 0
    @State private var extra = 0
    @State private var scen = 0
    @State private var extraFields: [Field] = []
    @State private var loaded = false

    var body: some View {
        let s = app.session!
        ScrollView {
            VStack(spacing: 12) {
                TitledCard(icon: .search, color: UI.GREY6E, title: "Pretraga proizvoda",
                           sub: "Ne razlikuje velika i mala slova, radi i po delu teksta") {
                    VStack(alignment: .leading, spacing: 0) {
                        CheckBox(text: "Item code", on: $code).padding(.top, 8)
                        CheckBox(text: "Item name", on: $name)
                        T("Dodatno polje za pretragu", 13, UI.SUB, true).padding(.top, 12)
                        Dropdown(options: ["(nijedno)"] + extraFields.map { $0.label + "  (" + $0.column + ")" }, selection: $extra)
                            .padding(.top, 6)
                        T("Za dodatno polje aplikacija jednom učita sve artikle i pretražuje ih lokalno.", 12, UI.GREY)
                    }
                }
                TitledCard(icon: .tune, color: UI.PRIMARY, title: "Scenario", sub: "Koristi se scenario prodavnice koji nije Items") {
                    Dropdown(options: s.scenarios.map { $0.title + ($0.key.isEmpty ? "" : "  [" + $0.key + "]") },
                             selection: $scen, enabled: s.scenarios.count > 1)
                        .padding(.top, 12)
                }
                TitledCard(icon: .scan, color: UI.ACCENT, title: "Barkod skener", sub: "Motor i kodovi koje kamera čita") {
                    VStack(alignment: .leading, spacing: 0) {
                        T("Motor za čitanje barkoda (kamera)", 13, UI.SUB, true).padding(.top, 12)
                        Dropdown(options: ["AVFoundation (Apple)", "Vision (Apple, bolji za oštećene i sitne kodove) – podrazumevani"], selection: $engine)
                            .padding(.top, 6)
                        T("Ako izabrani motor ne radi na ovom uređaju, aplikacija sama koristi AVFoundation.", 12, UI.GREY)
                        CheckBox(text: "Čitaj QR kodove (i Data Matrix / PDF417)", on: $qr).padding(.top, 8)
                        T("Kada je isključeno, kamera čita samo obične (linijske) barkodove.", 12, UI.GREY)
                    }
                }
                PrimaryButton(title: "Sačuvaj", color: UI.PRIMARY) { save() }.padding(.top, 4)
                FlatButton(title: "Osveži keš artikala i layout-a", color: UI.PRIMARY) {
                    app.run({ s.clearItemCache(); _ = try s.layouts(true) }, done: { _ in app.showToast("Keš osvežen") })
                }.padding(.top, -4)
            }.padding(14)
        }
        .chrome("Podešavanja")
        .onAppear {
            if loaded { return }
            loaded = true
            code = s.server.searchCode
            name = s.server.searchName
            qr = Prefs.ui.bool(forKey: "readQr")
            engine = scanEngine() == "vision" ? 1 : 0
            extraFields = s.fields.filter { $0.column.lowercased() != "itemcode" && $0.column.lowercased() != "itemname" }
            extra = (extraFields.firstIndex { $0.column == s.server.extraField }.map { $0 + 1 }) ?? 0
            scen = s.scenarios.firstIndex { $0.id == s.scenarioId } ?? 0
        }
    }

    private func save() {
        guard let s = app.session else { return }
        Prefs.ui.set(qr, forKey: "readQr")
        Prefs.ui.set(engine == 1 ? "vision" : "avf", forKey: "scanEngine")
        s.server.searchCode = code
        s.server.searchName = name
        if extra <= 0 || extra > extraFields.count { s.server.extraField = ""; s.server.extraFieldLabel = "" }
        else { s.server.extraField = extraFields[extra - 1].column; s.server.extraFieldLabel = extraFields[extra - 1].label }
        if !s.server.searchCode && !s.server.searchName && s.server.extraField.isEmpty {
            app.showError("Izaberi bar jedno polje za pretragu.")
            return
        }
        let sc: Scenario? = scen >= 0 && scen < s.scenarios.count ? s.scenarios[scen] : nil
        let changed = sc != nil && sc!.id != s.scenarioId
        if let sc = sc { s.server.scenarioId = sc.id }
        ServerStore().save(s.server)
        if !changed { app.showToast("Sačuvano"); app.back(); return }
        app.run({ s.selectScenario(sc!) }, done: { _ in app.showToast("Sačuvano"); app.back() })
    }
}
