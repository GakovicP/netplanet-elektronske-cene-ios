import SwiftUI

/// Ekrani (kao Activity klase u Android verziji).
enum Screen: Hashable {
    case servers, link, unlink(String), items, esls, aps, monitoring, problems(String), settings
}

/// Dugme dijaloga (AlertDialog): pozitivno / negativno desno, neutralno levo.
struct DialogButton {
    enum Kind { case positive, negative, neutral }
    let title: String
    var kind: Kind = .positive
    /// false = dijalog ostaje otvoren (npr. provera servera pre cuvanja)
    var dismiss = true
    var action: () -> Void = {}
}

struct DialogSpec: Identifiable {
    let id = UUID()
    var title: String?
    var message: String?
    var content: AnyView?
    var buttons: [DialogButton]
    /// bez okvira i naslova (lista za izbor proizvoda)
    var plain = false
    /// false = dodir van dijaloga ga ne zatvara (setCancelable(false))
    var cancelable = true
}

/// Globalno stanje: sesija, navigacija, poruke, dijalozi, skener.
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var session: Session?
    @Published var path: [Screen] = []
    @Published var busy = 0
    @Published var toast: String?
    @Published var dialogs: [DialogSpec] = []
    @Published var showLog = false
    @Published var scanning = false
    /// poziva se sa ocitanim kodom posle zatvaranja kamere
    var scanHandler: ((String) -> Void)?

    /// Novi server koji je unet ali jos nije uspesno povezan.
    var pendingServer: Server?

    private var toastWork: DispatchWorkItem?
    private static let queue = DispatchQueue(label: "esl.jobs", qos: .userInitiated, attributes: .concurrent)

    // ------------------------------------------------------------ async (BaseActivity.run)

    func run<T>(_ progress: Bool = true, _ work: @escaping () throws -> T,
                done: @escaping (T) -> Void = { _ in }, fail: ((Error) -> Void)? = nil) {
        if progress { busy += 1 }
        AppState.queue.async {
            let r: Result<T, Error>
            do { r = .success(try work()) } catch { r = .failure(error) }
            DispatchQueue.main.async {
                if progress { self.busy = max(0, self.busy - 1) }
                switch r {
                case .success(let v): done(v)
                case .failure(let e):
                    if let f = fail { f(e) } else { self.showError(errMsg(e)) }
                }
            }
        }
    }

    // ------------------------------------------------------------ poruke

    /// Kratka poruka na dnu ekrana (Toast).
    func showToast(_ msg: String, long: Bool = false) {
        let m = UI.essence(msg)
        if m.isEmpty { return }
        toastWork?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { toast = m }
        let w = DispatchWorkItem { [weak self] in withAnimation(.easeIn(duration: 0.2)) { self?.toast = nil } }
        toastWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + (long ? 3.5 : 2.0), execute: w)
    }

    func showError(_ m: String) {
        UI.beepErr()
        showToast(m, long: true)
    }

    /// Statusne poruke se prikazuju kao kratak toast (uspeh i greska); informativne se ne prikazuju.
    func status(_ msg: String, _ color: Color) {
        if msg.isEmpty { return }
        if color == UI.OK || color == UI.ERR { showToast(msg, long: color == UI.ERR) }
    }

    func dialog(_ d: DialogSpec) { dialogs.append(d) }

    func confirm(_ message: String, _ yes: String, no: String = "Ne", _ action: @escaping () -> Void) {
        dialog(DialogSpec(message: message, buttons: [
            DialogButton(title: no, kind: .negative),
            DialogButton(title: yes, kind: .positive, action: action),
        ]))
    }

    func info(_ title: String, _ m: String) {
        dialog(DialogSpec(title: title, message: m, buttons: [DialogButton(title: "OK")]))
    }

    func closeDialog(_ id: UUID) { dialogs.removeAll { $0.id == id } }

    // ------------------------------------------------------------ podrska

    /// Podrska: telefoni i mail iz potpisane liste servera (kesirane); ako je nema, preuzme je.
    func showSupport() {
        if let sp = ServerList.support(), SupportView.has(sp) { supportDialog(sp); return }
        var err: String?
        run({ () -> J? in
            let r = ServerList.load()
            err = r.error
            return ServerList.support()
        }, done: { sp in
            if let sp = sp, SupportView.has(sp) { self.supportDialog(sp); return }
            let why = err ?? (sp == nil ? "U listi servera nema dela \"support\"." : "Telefon i mail za podršku nisu popunjeni.")
            self.showError("Podrška nije dostupna.\n" + why)
        })
    }

    private func supportDialog(_ sp: J) {
        let t = Json.s(sp, "title")
        dialog(DialogSpec(title: t.isEmpty ? "Podrška" : t, content: AnyView(SupportView(sp: sp)),
                          buttons: [DialogButton(title: "Zatvori")]))
    }

    // ------------------------------------------------------------ skeniranje kamerom

    func startScan(_ handler: @escaping (String) -> Void) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        scanHandler = handler
        scanning = true
    }

    func scanFinished(_ code: String?) {
        let h = scanHandler
        scanHandler = nil
        scanning = false
        if let c = code, let h = h {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { h(c) }
        }
    }

    // ------------------------------------------------------------ navigacija

    func open(_ s: Screen) { path.append(s) }

    func back() { if !path.isEmpty { path.removeLast() } }

    func loggedIn(_ s: Session) {
        path = []
        session = s
    }

    func loggedOut() {
        path = []
        session = nil
    }
}
