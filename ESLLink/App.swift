import SwiftUI

@main
struct ESLLinkApp: App {
    @StateObject private var app = AppState.shared

    init() {
        Brand.apply()
        // zaglavlje providno: boja pozadine ekrana, tamni naslov i ikonice
        let a = UINavigationBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(UI.BG)
        a.shadowColor = .clear
        a.titleTextAttributes = [.foregroundColor: UIColor(UI.TEXT), .font: UIFont.systemFont(ofSize: 20, weight: .medium)]
        UINavigationBar.appearance().standardAppearance = a
        UINavigationBar.appearance().scrollEdgeAppearance = a
        UINavigationBar.appearance().compactAppearance = a
        UINavigationBar.appearance().tintColor = UIColor(UI.TEXT)
    }

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(app)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            NavigationStack(path: $app.path) {
                Group {
                    if app.session == nil { LoginView() } else { MainView() }
                }
                .navigationDestination(for: Screen.self) { s in
                    switch s {
                    case .servers: ServersView()
                    case .link: LinkView()
                    case .unlink(let esl): UnlinkView(prefill: esl)
                    case .items: ItemListView()
                    case .esls: EslListView()
                    case .aps: ApListView()
                    case .monitoring: MonitoringView()
                    case .problems(let t): ProblemListView(type: t)
                    case .settings: SearchSettingsView()
                    }
                }
            }
            .tint(UI.TEXT)
            .id(app.lang + "#\(app.brandRev)")

            if let t = app.toast {
                VStack { Spacer(); ToastView(text: t) }.transition(.opacity).zIndex(5)
            }
            ForEach(app.dialogs) { d in DialogView(d: d).zIndex(10) }
            if app.showLog { LogView().zIndex(11) }
            if app.busy > 0 { BusyView().zIndex(20) }
        }
        .fullScreenCover(isPresented: $app.scanning, onDismiss: {
            if app.scanHandler != nil { app.scanFinished(nil) }
        }) {
            ScannerView { code in app.scanFinished(code) }
        }
    }
}

/// Zajednicki izgled ekrana: pozadina, ActionBar sa strelicom nazad, naslovom levo i ⋮ menijem.
struct ScreenChrome: ViewModifier {
    let title: String
    var back = true
    /// nil = samo "Dnevnik komunikacije", prazno = bez menija
    var menu: [(String, () -> Void)]? = nil
    @EnvironmentObject var app: AppState

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(UI.BG.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(UI.BG, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if back {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { app.back() } label: {
                            Image(systemName: "arrow.left").font(.system(size: 19, weight: .medium)).foregroundColor(UI.TEXT)
                        }
                    }
                }
                // naslov u sredini (na novom iOS-u levi elementi idu u mali krug i naslov se skracivao)
                ToolbarItem(placement: .principal) {
                    Text(L.t(title)).font(.system(size: 18, weight: .semibold)).foregroundColor(UI.TEXT).lineLimit(1)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    let items = menu ?? [("Dnevnik komunikacije", { app.showLog = true })]
                    if !items.isEmpty {
                    Menu {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, m in
                            Button(L.t(m.0)) { m.1() }
                        }
                    } label: {
                        Image(systemName: "ellipsis").rotationEffect(.degrees(90))
                            .font(.system(size: 18, weight: .bold)).foregroundColor(UI.TEXT)
                            .frame(width: 32, height: 32)
                    }
                    }
                }
            }
    }
}

extension View {
    func chrome(_ title: String, back: Bool = true, menu: [(String, () -> Void)]? = nil) -> some View {
        modifier(ScreenChrome(title: title, back: back, menu: menu))
    }
}

/// Vraca gest za povratak (prevuci sa leve ivice) iako je standardno dugme nazad sakriveno.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

/// Sadrzaj dijaloga: ako ne staje na ekran, skroluje se.
struct DialogScroll<C: View>: View {
    @ViewBuilder var content: () -> C
    var body: some View {
        ViewThatFits(in: .vertical) {
            content()
            ScrollView { content() }
        }
    }
}
