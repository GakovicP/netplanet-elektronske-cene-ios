import SwiftUI
import UIKit

/// Izgled prodavnice: logo i boje po domenu naloga, iz potpisane liste servera ("brands").
/// Logo se preuzima jednom posle prijave (u pozadini) i cuva na telefonu.
enum Brand {
    private static let p = UserDefaults(suiteName: "brand") ?? .standard
    private static let DEF_PRIMARY: UInt32 = 0xFF4C4C4E, DEF_DARK: UInt32 = 0xFF2F2F31, DEF_ACCENT: UInt32 = 0xFFF57921

    private static var logoURL: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent("brand_logo.png")
    }

    /// Primeni sacuvane boje (na pokretanju i posle prijave).
    static func apply() {
        let pr = p.object(forKey: "primary") as? Int
        let ac = p.object(forKey: "accent") as? Int
        UI.PRIMARY = Color(argb: UInt32(truncatingIfNeeded: pr ?? Int(DEF_PRIMARY)))
        UI.ACCENT = Color(argb: UInt32(truncatingIfNeeded: ac ?? Int(DEF_ACCENT)))
        UI.PRIMARY_DARK = Color(argb: pr.map { darker(UInt32(truncatingIfNeeded: $0)) } ?? DEF_DARK)
        // pozadina: boja prodavnice ili bela; tamna tema telefona uvek tamna pozadina
        let bg = (p.object(forKey: "background") as? Int).map { UInt32(truncatingIfNeeded: $0) } ?? 0xFFFFFFFF
        UI.BG = Color(light: bg, dark: 0xFF121214)
        let acc = UInt32(truncatingIfNeeded: ac ?? Int(DEF_ACCENT))
        let prc = UInt32(truncatingIfNeeded: pr ?? Int(DEF_PRIMARY))
        UI.INK = Color(light: prc, dark: mix(prc, 0xFFFFFFFF, 0.3))
        UI.SOFT = Color(light: mix(acc, 0xFFFFFFFF, 0.12), dark: mix(acc, 0xFF1F1F22, 0.22))
    }

    /// Mesavina boja: udeo `a` boje c preko pozadine b.
    private static func mix(_ c: UInt32, _ b: UInt32, _ a: Double) -> UInt32 {
        func ch(_ s: UInt32) -> UInt32 { UInt32(Double((c >> s) & 0xFF) * a + Double((b >> s) & 0xFF) * (1 - a)) << s }
        return 0xFF000000 | ch(16) | ch(8) | ch(0)
    }

    private static func darker(_ c: UInt32) -> UInt32 {
        let r = UInt32(Double((c >> 16) & 0xFF) * 0.62), g = UInt32(Double((c >> 8) & 0xFF) * 0.62), b = UInt32(Double(c & 0xFF) * 0.62)
        return 0xFF000000 | (r << 16) | (g << 8) | b
    }

    /// Logo prodavnice ako postoji, inace nil (koristi se NetPlanet planeta).
    static func logo() -> UIImage? {
        guard p.bool(forKey: "hasLogo"), let d = try? Data(contentsOf: logoURL) else { return nil }
        return UIImage(data: d)
    }

    private static func color(_ s: String, _ def: UInt32) -> UInt32 {
        var h = s.trimmed
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6 || h.count == 8, let v = UInt32(h, radix: 16) else { return def }
        return h.count == 6 ? 0xFF000000 | v : 0xFF000000 | (v & 0xFFFFFF)
    }

    /// Posle uspesne prijave: nadji izgled za domen naloga, sacuvaj boje i (u pozadini) preuzmi logo.
    static func afterLogin(_ account: String, changed: @escaping () -> Void) {
        guard let br = find(account) else {
            for k in ["primary", "accent", "background", "hasLogo", "logoUrl"] { p.removeObject(forKey: k) }
            try? FileManager.default.removeItem(at: logoURL)
            apply()
            return
        }
        let pr = Json.s(br, "primary"), ac = Json.s(br, "accent"), bgc = Json.s(br, "background")
        if bgc.isEmpty { p.removeObject(forKey: "background") } else { p.set(Int(color(bgc, 0xFFFFFFFF)), forKey: "background") }
        if pr.isEmpty { p.removeObject(forKey: "primary") } else { p.set(Int(color(pr, DEF_PRIMARY)), forKey: "primary") }
        if ac.isEmpty { p.removeObject(forKey: "accent") } else { p.set(Int(color(ac, DEF_ACCENT)), forKey: "accent") }
        apply()
        let logo = resolve(Json.s(br, "logo"))
        if logo.isEmpty {
            p.set(false, forKey: "hasLogo"); p.removeObject(forKey: "logoUrl")
            try? FileManager.default.removeItem(at: logoURL)
        } else if logo != (p.string(forKey: "logoUrl") ?? "") || !FileManager.default.fileExists(atPath: logoURL.path) {
            download(logo, changed)
        }
    }

    private static func find(_ account: String) -> J? {
        let acc = account.trimmed.lowercased()
        let dom = acc.contains("@") ? String(acc[acc.index(after: acc.lastIndex(of: "@")!)...]) : ""
        guard let root = Json.parse(UserDefaults(suiteName: "serverlist")?.string(forKey: "cache2") ?? "") as? J,
              let brands = root["brands"] as? J else { return nil }
        for (k, v) in brands {
            let kl = k.trimmed.lowercased()
            if kl == acc || (!dom.isEmpty && (kl == dom || kl == "@" + dom)) { return v as? J }
        }
        return nil
    }

    /// Relativna adresa loga ("logos/voli.png") se racuna od adrese liste servera.
    private static func resolve(_ logo: String) -> String {
        let l = logo.trimmed
        if l.isEmpty || l.contains("://") { return l }
        return URL(string: l, relativeTo: URL(string: ServerList.url()))?.absoluteString ?? ""
    }

    private static func download(_ url: String, _ changed: @escaping () -> Void) {
        guard let u = URL(string: url) else { return }
        var r = URLRequest(url: u)
        r.timeoutInterval = 10
        URLSession.shared.dataTask(with: r) { data, resp, _ in
            guard let d = data, d.count < 2 * 1024 * 1024, (resp as? HTTPURLResponse)?.statusCode == 200,
                  UIImage(data: d) != nil else { return } // samo slika, do 2 MB
            try? d.write(to: logoURL, options: .atomic)
            p.set(true, forKey: "hasLogo")
            p.set(url, forKey: "logoUrl")
            DispatchQueue.main.async { changed() }
        }.resume()
    }
}

/// Logo u krugu: logo prodavnice ili NetPlanet planeta.
struct BrandLogo: View {
    @EnvironmentObject var app: AppState
    let size: CGFloat
    var body: some View {
        if let img = app.brandLogo {
            Image(uiImage: img).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Image("np_logo").resizable().scaledToFit().frame(width: size, height: size)
        }
    }
}

/// NetPlanet logo u dnu ekrana.
struct NetPlanetFooter: View {
    var onDark = false
    var body: some View {
        Image("np_wordmark").resizable().scaledToFit().frame(height: onDark ? 27 : 23)
            .padding(.horizontal, onDark ? 16 : 0).padding(.vertical, onDark ? 8 : 0)
            .background(onDark ? RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.95)) : nil)
            .opacity(onDark ? 1 : 0.85)
    }
}
