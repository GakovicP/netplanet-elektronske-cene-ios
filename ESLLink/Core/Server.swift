import Foundation

/// Jedna serverska konfiguracija.
final class Server {
    var id = UUID().uuidString.lowercased()
    var name = ""
    var url = ""
    var verified = false          // true kada je bar jednom uspesno ostvarena prijava
    var lastAccount = ""
    var manual = false            // rucno dodat u aplikaciji (samo takvi se prikazuju u listi servera)

    // Napredno: "third" API (poglavlje 10 prirucnika) za link / unlink
    var thirdUrl = ""             // prazno = isti host:port kao server
    var thirdUser = ""            // prazno = isti nalog kao za prijavu
    var thirdPass = ""            // prazno = ista lozinka kao za prijavu
    var thirdMd5 = false          // salji MD5 lozinku na third login
    var bindPath = "third/bind/v1/bind"
    var unbindPath = "third/bind/v1/unBind"
    var trustAll = false          // prihvati sve SSL sertifikate
    var fromList = false          // dolazi iz liste servera (ne cuva se)

    // Scenario i pretraga
    var scenarioId = ""           // prazno = automatski (jedini koji nije Items)
    var searchCode = true
    var searchName = true
    var extraField = ""           // columnName dodatnog polja (npr. field_7)
    var extraFieldLabel = ""
    var autoLink = true
    var remember = false
    var savedPass = ""

    static func norm(_ u0: String) -> String {
        var u = u0.trimmed
        if u.isEmpty { return u }
        if !u.contains("://") { u = "http://" + u }
        if !u.hasSuffix("/") { u += "/" }
        return u
    }

    func baseUrl() -> String { Server.norm(url) }

    func thirdBase() -> String {
        if !thirdUrl.trimmed.isEmpty { return Server.norm(thirdUrl) }
        guard let u = URLComponents(string: baseUrl()), let scheme = u.scheme, let host = u.host else { return baseUrl() }
        return "\(scheme)://\(host)\(u.port.map { ":\($0)" } ?? "")/"
    }

    func bind() -> String { Server.trimSlash(bindPath, "third/bind/v1/bind") }
    func unbind() -> String { Server.trimSlash(unbindPath, "third/bind/v1/unBind") }

    private static func trimSlash(_ p0: String, _ def: String) -> String {
        var p = p0.trimmed
        if p.isEmpty { return def }
        while p.hasPrefix("/") { p.removeFirst() }
        return p
    }

    /// Kratak naziv za listu na prijavi: naziv, ili samo host ako naziv nije unet.
    func shortName() -> String {
        if !name.trimmed.isEmpty { return name.trimmed }
        return URLComponents(string: baseUrl())?.host ?? url
    }

    func display() -> String {
        if !name.trimmed.isEmpty { return name.trimmed + "  (" + url + ")" }
        return url
    }

    func toJson() -> J {
        [
            "id": id, "name": name, "url": url, "verified": verified, "lastAccount": lastAccount,
            "thirdUrl": thirdUrl, "thirdUser": thirdUser, "thirdPass": thirdPass, "thirdMd5": thirdMd5,
            "bindPath": bindPath, "unbindPath": unbindPath, "trustAll": trustAll, "scenarioId": scenarioId,
            "searchCode": searchCode, "searchName": searchName, "extraField": extraField,
            "extraFieldLabel": extraFieldLabel, "autoLink": autoLink, "remember": remember, "manual": manual,
            "savedPass": Data(savedPass.utf8).base64EncodedString(),
        ]
    }

    static func fromJson(_ o: J) -> Server {
        let s = Server()
        func str(_ k: String, _ d: String) -> String { o[k] == nil ? d : Json.s(o, k) }
        s.id = str("id", s.id)
        s.name = str("name", "")
        s.url = str("url", "")
        s.verified = Json.bool(o, "verified", false)
        s.manual = o["manual"] == nil ? !ServerList.isBuiltin(s.url) : Json.bool(o, "manual", false)
        s.lastAccount = str("lastAccount", "")
        s.thirdUrl = str("thirdUrl", "")
        s.thirdUser = str("thirdUser", "")
        s.thirdPass = str("thirdPass", "")
        s.thirdMd5 = Json.bool(o, "thirdMd5", false)
        s.bindPath = str("bindPath", s.bindPath)
        s.unbindPath = str("unbindPath", s.unbindPath)
        s.trustAll = Json.bool(o, "trustAll", false)
        s.scenarioId = str("scenarioId", "")
        s.searchCode = Json.bool(o, "searchCode", true)
        s.searchName = Json.bool(o, "searchName", true)
        s.extraField = str("extraField", "")
        s.extraFieldLabel = str("extraFieldLabel", "")
        s.autoLink = Json.bool(o, "autoLink", true)
        s.remember = Json.bool(o, "remember", false)
        if let d = Data(base64Encoded: str("savedPass", "")), let p = String(data: d, encoding: .utf8) { s.savedPass = p }
        return s
    }

    /// Delovi adrese za unos: (sema, host(+putanja), port).
    func parts() -> (String, String, String) {
        var scheme = "http", host = "", port = "8085", path = ""
        if !url.trimmed.isEmpty, let u = URLComponents(string: baseUrl()) {
            scheme = u.scheme ?? "http"
            host = u.host ?? ""
            port = u.port.map { String($0) } ?? (scheme == "https" ? "443" : "80")
            path = u.path
            while path.hasSuffix("/") { path.removeLast() }
        }
        return (scheme, host + path, port)
    }

    static func build(_ scheme: String, _ hostPath: String, _ port: String) -> String {
        var h = hostPath.trimmed
        if let r = h.range(of: "://") { h = String(h[r.upperBound...]) }
        var path = ""
        if let sl = h.firstIndex(of: "/") { path = String(h[sl...]); h = String(h[..<sl]) }
        if let col = h.lastIndex(of: ":"), col > h.startIndex { h = String(h[..<col]) }  // port se unosi posebno
        let p = port.trimmed
        return norm(scheme + "://" + h + (p.isEmpty ? "" : ":" + p) + path)
    }

    func copy() -> Server { Server.fromJson(toJson()) }
}

/// Cuva sve serverske konfiguracije i poslednji korisceni server.
struct ServerStore {
    private let p = UserDefaults(suiteName: "servers") ?? .standard

    func all() -> [Server] {
        guard let a = Json.parse(p.string(forKey: "list") ?? "[]") as? [Any] else { return [] }
        return a.compactMap { $0 as? J }.map(Server.fromJson)
    }

    func verified() -> [Server] { all().filter { $0.verified } }

    /// Samo rucno dodati serveri (za ekran Serveri).
    func manual() -> [Server] { all().filter { $0.manual } }

    func get(_ id: String) -> Server? { all().first { $0.id == id } }

    func save(_ s: Server) {
        var l = all()
        if let i = l.firstIndex(where: { $0.id == s.id }) { l[i] = s } else { l.append(s) }
        write(l)
    }

    func delete(_ id: String) {
        write(all().filter { $0.id != id })
        if id == lastId() { p.removeObject(forKey: "last") }
    }

    private func write(_ l: [Server]) { p.set(Json.string(l.map { $0.toJson() }), forKey: "list") }

    func lastId() -> String { p.string(forKey: "last") ?? "" }
    func setLast(_ id: String) { p.set(id, forKey: "last") }

    /// Izbor servera za prijavu: "" = automatski, inace id rucno unetog servera.
    func mode() -> String { p.string(forKey: "mode") ?? "" }
    func setMode(_ id: String) { p.set(id, forKey: "mode") }

    /// Rucno izabran server, ili nil za automatski izbor.
    func fixed() -> Server? {
        let m = mode()
        guard !m.isEmpty, let s = get(m), s.manual else { return nil }
        return s
    }
}

/// Podesavanja interfejsa (kao SharedPreferences "ui" u Android verziji).
enum Prefs {
    static let ui = UserDefaults(suiteName: "ui") ?? .standard
}
