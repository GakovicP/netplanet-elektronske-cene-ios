import SwiftUI

/// Pregled stanja sistema sa automatskim osvezavanjem.
struct MonitoringView: View {
    @EnvironmentObject var app: AppState
    @State private var auto = true
    @State private var visible = false
    @State private var data: (J?, J?, J?)?
    @State private var updated = ""
    @State private var updatedErr = false
    @State private var loading = false
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(icon: .chart, title: "Monitoring", sub: app.session?.storeName ?? "")
                HStack(spacing: 12) {
                    PrimaryButton(title: "Osveži", color: UI.PRIMARY) { refresh(true) }.fixedSize()
                    CheckBox(text: "Auto (30 s)", on: $auto)
                }.padding(.top, 12)
                T(updated, 12, updatedErr ? UI.ERR : UI.GREY).padding(.top, 6)
                if let d = data { grid(d) }
            }.padding(14)
        }
        .chrome("Monitoring")
        .onAppear {
            visible = true
            refresh(data == nil)
        }
        .onDisappear { visible = false }
        .onReceive(timer) { _ in
            if visible && auto && !loading { refresh(false) }
        }
    }

    private func refresh(_ progress: Bool) {
        guard let S = app.session else { return }
        loading = true
        app.run(progress, { () -> (J?, J?, J?) in
            let b: J = ["storeId": S.storeId, "merchantId": S.merchantId, "agentId": S.agentId]
            let r0 = Json.obj(try? S.api.app("app/tag/v1/countTag", b), "data")
            let r1 = Json.obj(try? S.api.app("app/coor/v1/coor/statistics", ["storeId": S.storeId]), "data")
            let r2 = Json.obj(try? S.api.app("app/item/v1/tag/statistics", ["storeId": S.storeId, "scenarioId": S.scenarioId]), "data")
            if r0 == nil && r1 == nil && r2 == nil { throw AppError.api("Server nije vratio podatke za monitoring") }
            return (r0, r1, r2)
        }, done: { r in
            loading = false
            data = r
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "HH:mm:ss"
            updated = "Ažurirano: " + f.string(from: Date())
            updatedErr = false
        }, fail: { e in
            loading = false
            updated = "Greška: " + errMsg(e)
            updatedErr = true
        })
    }

    private static func blend(_ c: UInt32) -> UInt32 {
        let r = min(255, ((c >> 16) & 0xFF) + 40), g = min(255, ((c >> 8) & 0xFF) + 40), b = min(255, (c & 0xFF) + 40)
        return 0xFF000000 | (r << 16) | (g << 8) | b
    }

    private static func first(_ a: String, _ b: String) -> String { a.isEmpty ? b : a }

    private static let P: UInt32 = 0xFF4C4C4E, OKc: UInt32 = 0xFF2E7D32, ERRc: UInt32 = 0xFFD32F2F, WARNc: UInt32 = 0xFFEF6C00

    @ViewBuilder private func grid(_ d: (J?, J?, J?)) -> some View {
        let s = { (o: J?, k: String) in Json.s(o, k) }
        VStack(alignment: .leading, spacing: 10) {
            if let t = d.0 {
                Caption("ESL etikete").padding(.top, 20)
                row(tile("Ukupno", s(t, "tagTotal"), Self.P, .esls),
                    tile("Online", s(t, "onlineNumber"), Self.OKc, .esls))
                row(tile("Offline", s(t, "offlineNumber"), Self.ERRc, .problems("offline")),
                    tile("Linkovano", Self.first(s(t, "bindNumber"), s(t, "linkNumber")), 0xFFF57921, .esls))
                row(tile("Nelinkovano", Self.first(s(t, "unbindNumber"), s(t, "unlinkNumber")), 0xFF757575, .esls), nil)
            }
            if let c = d.1 {
                Caption("Bazne stanice (AP)").padding(.top, 20)
                row(tile("Ukupno", s(c, "total"), Self.P, .aps), tile("Povezane", s(c, "connect"), Self.OKc, .aps))
                row(tile("Nepovezane", s(c, "unConnect"), Self.ERRc, .aps), nil)
            }
            if let it = d.2 {
                Caption("Artikli (" + (app.session?.scenarioName ?? "") + ")").padding(.top, 20)
                row(tile("Ukupno", s(it, "total"), Self.P, .items), tile("Linkovani", s(it, "bindTotal"), Self.OKc, .items))
                row(tile("Nelinkovani", s(it, "unBindTotal"), 0xFF757575, .items), nil)
            }
        }
    }

    private func row(_ a: AnyView, _ b: AnyView?) -> some View {
        HStack(spacing: 10) {
            a.frame(maxWidth: .infinity)
            if let b = b { b.frame(maxWidth: .infinity) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
        }
    }

    private func tile(_ label: String, _ value: String, _ color: UInt32, _ target: Screen) -> AnyView {
        AnyView(Button { app.open(target) } label: {
            VStack(spacing: 0) {
                T(value.isEmpty ? "–" : value, 30, .white, true)
                T(label, 13, Color.white.opacity(0.93))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(argb: color), Color(argb: Self.blend(color))],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .elevation(2))
        }.buttonStyle(PressStyle()))
    }
}
