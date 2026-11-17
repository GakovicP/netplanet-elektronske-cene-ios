import Foundation
import CryptoKit

/// Lista servera: ugradjeni serveri + potpisan fajl sa interneta (servers.json + servers.json.sig).
/// Isto kao ServerList.java u Android verziji.
enum ServerList {
    static let DEFAULT_URL = "http://88.198.177.187:8090/netplanet/servers.json"

    /// Javni kljuc (ECDSA P-256, X.509 DER base64). servers.json.sig = base64(openssl dgst -sha256 -sign kljuc servers.json).
    static let PUBLIC_KEY = "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEIEMXb5B5rwENzpm/Vsc+NekYCM4A9+1R+nDly3g2DcSLGWWaw1H9E/74Xl1Em/jinFsTlYizFkB3LqyyS2xnTg=="

    /// Serveri ugradjeni u aplikaciju (rade i bez liste sa interneta).
    static func isBuiltin(_ url: String) -> Bool {
        let n = Server.norm(url).lowercased()
        return BUILTIN.contains { Server.norm($0.1).lowercased() == n }
    }

    static let BUILTIN: [(String, String)] = [
        ("", "http://23.88.63.75:8085"),
        ("", "http://37.27.183.134:8085"),
        ("", "http://46.62.129.1:8085"),
        ("", "http://46.224.14.94:8085"),
        ("", "http://46.225.172.59:8085"),
        ("", "http://49.13.217.99:8085"),
        ("", "http://91.107.234.144:8085"),
        ("", "http://116.203.60.108:8085"),
        ("", "http://142.132.163.199:8085"),
        ("", "http://159.69.189.109:8085"),
        ("", "http://167.235.237.33:8085"),
        ("", "http://178.104.241.123:8085"),
        ("", "http://178.105.255.110:8085"),
        ("", "http://188.245.41.58:8085"),
    ]

    struct Entry {
        var name = ""
        var url = ""
        var disabled = false
        var builtin = false
        var extra: J?
        var accounts: [String] = []

        /// Da li nalog pripada ovom serveru (tacno ime ili sablon sa * i ?).
        func matches(_ acc: String) -> Bool {
            let a = acc.trimmed.lowercased()
            return accounts.contains { ServerList.glob($0.trimmed.lowercased(), a) }
        }
    }

    struct Result {
        var entries: [Entry] = []
        var fromCache = false
        var error: String?
    }

    private static let p = UserDefaults(suiteName: "serverlist") ?? .standard

    static func url() -> String { DEFAULT_URL }
    static func cachedAt() -> Double { p.double(forKey: "at2") }
    static func cached() -> [Entry] { parse(p.string(forKey: "cache2") ?? "") }

    /// Podaci za podrsku iz poslednje proverene liste.
    static func support() -> J? {
        (Json.parse(p.string(forKey: "cache2") ?? "") as? J)?["support"] as? J
    }

    static func builtin() -> [Entry] {
        var l: [Entry] = []
        for b in BUILTIN {
            var e = Entry()
            e.name = b.0; e.url = b.1; e.builtin = true
            add(&l, e)
        }
        return l
    }

    /// Ugradjeni + lista sa interneta (novi se dodaju, isti url menja naziv/naloge, disabled sakriva).
    static func merge(_ remote: [Entry]) -> [Entry] {
        var out = builtin()
        for r0 in remote {
            var r = r0
            let n = Server.norm(r.url).lowercased()
            let idx = out.firstIndex { Server.norm($0.url).lowercased() == n }
            if r.disabled { if let i = idx { out.remove(at: i) }; continue }
            if let i = idx {
                if r.name.isEmpty { r.name = out[i].name }
                r.builtin = true
                out[i] = r
            } else { out.append(r) }
        }
        return out
    }

    /// Preuzima listu i potpis; ako ne uspe, koristi poslednju proverenu (fromCache=true).
    static func load() -> Result {
        var r = Result()
        var remote: [Entry]
        do {
            let u = url()
            let raw = try get(u)
            let sig = try get(u + ".sig")
            if !verify(raw, sig) { throw AppError.msg("Lista servera nema ispravan potpis, odbačena je.") }
            let txt = String(data: raw, encoding: .utf8) ?? ""
            remote = parse(txt)
            if remote.isEmpty && !txt.contains("servers") { throw AppError.msg("Lista servera je neispravna.") }
            p.set(txt, forKey: "cache2")
            p.set(Date().timeIntervalSince1970 * 1000, forKey: "at2")
        } catch {
            r.error = errMsg(error)
            remote = cached()
            r.fromCache = true
        }
        r.entries = merge(remote)
        return r
    }

    static func verify(_ data: Data, _ sigFile: Data) -> Bool {
        let b = (String(data: sigFile, encoding: .ascii) ?? "").components(separatedBy: .whitespacesAndNewlines).joined()
        guard let sig = Data(base64Encoded: b), let kd = Data(base64Encoded: PUBLIC_KEY),
              let key = try? P256.Signing.PublicKey(derRepresentation: kd),
              let s = try? P256.Signing.ECDSASignature(derRepresentation: sig) else { return false }
        return key.isValidSignature(s, for: data)
    }

    private static func get(_ u: String) throws -> Data {
        let full = u + (u.contains("?") ? "&" : "?") + "t=" + String(Int64(Date().timeIntervalSince1970 * 1000))
        guard let url = URL(string: full) else { throw AppError.msg("Neispravan link liste servera.") }
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
        r.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 5
        c.timeoutIntervalForResource = 9
        let session = URLSession(configuration: c)
        let sem = DispatchSemaphore(value: 0)
        var data: Data?, resp: URLResponse?, err: Error?
        session.dataTask(with: r) { d, rs, e in data = d; resp = rs; err = e; sem.signal() }.resume()
        sem.wait()
        session.finishTasksAndInvalidate()
        if let e = err { Log.add("GET " + u, "", -1, String(describing: e)); throw e }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let d = data ?? Data()
        let txt = String(data: d, encoding: .utf8) ?? ""
        Log.add("GET " + u, "", code, txt.count > 600 ? String(txt.prefix(600)) + "…" : txt)
        if code >= 400 { throw AppError.msg((u.hasSuffix(".sig") ? "Potpis liste" : "Lista servera") + " nije dostupan (HTTP \(code)).") }
        return d
    }

    static func parse(_ txt: String) -> [Entry] {
        var l: [Entry] = []
        var t = txt.trimmed
        if t.hasPrefix("\u{FEFF}") { t = String(t.dropFirst()).trimmed }
        if t.isEmpty { return l }
        let o = Json.parse(t)
        let a: [Any]? = (o as? [Any]) ?? ((o as? J)?["servers"] as? [Any])
        for it in a ?? [] {
            var e = Entry()
            if let s = it as? String { e.url = s }
            else if let jo = it as? J {
                e.url = jo["url"] != nil ? Json.s(jo, "url") : Json.s(jo, "address")
                e.name = Json.s(jo, "name")
                e.disabled = Json.bool(jo, "disabled", false)
                e.extra = jo
                if let aa = jo["accounts"] as? [Any] { for x in aa { addAcc(&e, Json.str(x)) } }
                else if let s = jo["accounts"] as? String { addAcc(&e, s) }
            }
            add(&l, e)
        }
        return l
    }

    private static func addAcc(_ e: inout Entry, _ list: String) {
        for x in list.components(separatedBy: CharacterSet(charactersIn: ",;").union(.whitespacesAndNewlines)) where !x.trimmed.isEmpty {
            e.accounts.append(x.trimmed)
        }
    }

    static func glob(_ p: String, _ s: String) -> Bool {
        var re = "^"
        for ch in p {
            if ch == "*" { re += ".*" } else if ch == "?" { re += "." }
            else { re += NSRegularExpression.escapedPattern(for: String(ch)) }
        }
        re += "$"
        return s.range(of: re, options: .regularExpression) != nil
    }

    private static func add(_ l: inout [Entry], _ e0: Entry) {
        var e = e0
        e.url = e.url.trimmed
        if e.url.isEmpty { return }
        e.url = Server.norm(e.url)
        let n = e.url.lowercased()
        if l.contains(where: { Server.norm($0.url).lowercased() == n }) { return }
        l.append(e)
    }

    /// Svi serveri: iz liste + rucno dodati (verifikovani) + novi rucni.
    static func all(_ store: ServerStore, _ entries: [Entry], _ pending: Server?) -> [Server] {
        candidates(store, entries, pending, nil)
    }

    /// acc == nil: svi serveri. Inace samo oni ciji se "accounts" poklapaju (+ pending).
    static func candidates(_ store: ServerStore, _ entries: [Entry], _ pending: Server?, _ acc: String?) -> [Server] {
        let stored = store.all()
        var out: [Server] = []
        for e in entries {
            let n = Server.norm(e.url)
            if let a = acc, !e.matches(a) { continue }
            let s: Server
            if let x = stored.first(where: { Server.norm($0.url).lowercased() == n.lowercased() }) { s = x }
            else { s = Server(); s.url = n }
            if !e.name.isEmpty { s.name = e.name }
            if let x = e.extra {
                if x["scenarioId"] != nil { s.scenarioId = Json.s(x, "scenarioId") }
                if x["trustAll"] != nil { s.trustAll = Json.bool(x, "trustAll", false) }
            }
            s.fromList = true
            out.append(s)
        }
        var extra: [Server] = []
        if let p = pending { extra.append(p) }
        if acc == nil { extra += store.verified() }
        for s in extra where !out.contains(where: { Server.norm($0.url).lowercased() == Server.norm(s.url).lowercased() }) {
            out.append(s)
        }
        return out
    }
}
