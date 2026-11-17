import Foundation
import CryptoKit
import UIKit

/// Greske aplikacije.
enum AppError: LocalizedError {
    /// Server je odgovorio, ali sa state=false ili neuspesnim kodom.
    case api(String)
    /// HTTP greska (4xx/5xx).
    case http(Int, String)
    /// Ostalo.
    case msg(String)

    var errorDescription: String? {
        switch self {
        case .api(let m), .http(_, let m), .msg(let m): return m
        }
    }
}

/// Prihvata self-signed sertifikate kada je ukljuceno u podesavanjima servera.
private final class TrustAllDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let t = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: t))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

/// HTTP sloj prema BOWTZ serveru (APP API + "third" API iz poglavlja 10).
/// Pozivi su sinhroni i uvek se izvrsavaju van glavne niti (vidi AppState.run).
final class Api {
    let server: Server
    var token: String?
    var jsession: String?
    var account = ""
    var plainPassword = ""

    /// Timeout zahteva u sekundama (prijava na vise servera koristi kraci).
    var timeout: TimeInterval = 45

    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 120
        c.timeoutIntervalForResource = 180
        c.waitsForConnectivity = false
        return server.trustAll ? URLSession(configuration: c, delegate: TrustAllDelegate(), delegateQueue: nil)
                               : URLSession(configuration: c)
    }()

    init(_ s: Server) { server = s }

    // ------------------------------------------------------------ util

    static func md5(_ s: String) -> String {
        Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func empty(_ s: String?) -> Bool { s == nil || s!.trimmed.isEmpty || s == "null" }

    private static func shorten(_ s0: String) -> String {
        let s = s0.replacingRegex("<[^>]*>", with: " ").replacingRegex("\\s+", with: " ").trimmed
        return s.count > 200 ? String(s.prefix(200)) + "..." : s
    }

    func http(_ url: String, _ body: String) throws -> String {
        guard let u = URL(string: url) else { throw AppError.msg("Neispravna adresa: \(url)") }
        var r = URLRequest(url: u, timeoutInterval: timeout)
        r.httpMethod = "POST"
        r.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = token { r.setValue(t, forHTTPHeaderField: "Authorization") }
        r.httpBody = Data(body.utf8)

        let sem = DispatchSemaphore(value: 0)
        var data: Data?, resp: URLResponse?, err: Error?
        session.dataTask(with: r) { d, rs, e in data = d; resp = rs; err = e; sem.signal() }.resume()
        sem.wait()

        if let e = err {
            Log.add(url, body, -1, String(describing: e))
            throw e
        }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        Log.add(url, body, code, text)
        if code >= 400 { throw AppError.http(code, "HTTP \(code)" + (text.isEmpty ? "" : ": " + Api.shorten(text))) }
        return text
    }

    private static func parse(_ r: String) throws -> J {
        if let o = Json.parse(r) as? J { return o }
        throw AppError.api("Neočekivan odgovor servera: " + shorten(r))
    }

    // ------------------------------------------------------------ APP API

    /// Poziva APP interfejs; baca AppError.api ako je state=false.
    @discardableResult
    func app(_ path: String, _ body: J?) throws -> J {
        let o = try Api.parse(http(server.baseUrl() + path, Json.string(body ?? [:])))
        if !Json.bool(o, "state", false) {
            var m = Json.s(o, "message")
            if Api.empty(m) { m = "Greška servera (kod \(Json.s(o, "code")))" }
            throw AppError.api(m)
        }
        return o
    }

    func login(_ acc: String, _ pass: String) throws -> J {
        let b: J = ["account": acc, "password": Api.md5(pass), "loginOs": "ios " + UIDeviceVersion.value]
        token = nil
        let o = try app("app/user/v1/login/password", b)
        guard let d = Json.obj(o, "data"), !Api.empty(Json.s(d, "token")) else { throw AppError.api("Server nije vratio token") }
        token = Json.s(d, "token")
        account = acc
        plainPassword = pass
        jsession = nil
        return d
    }

    /// Provera da li na adresi odgovara BOWTZ server (bez prijave).
    func ping() throws {
        let r = try http(server.baseUrl() + "app/language/v1/getList", "{}")
        let o: J
        do { o = try Api.parse(r) } catch {
            throw AppError.api("Na ovoj adresi odgovara neki server, ali to nije BOWTZ API. Proveri adresu, port i putanju.")
        }
        if o["state"] == nil && o["code"] == nil { throw AppError.api("Server ne odgovara kao BOWTZ API. Proveri adresu, port i putanju.") }
    }

    func logout() { _ = try? app("app/user/v1/logout", [:]) }

    // ------------------------------------------------------------ THIRD API (link / unlink)

    /// Sifre prodavnice (iz app/store/v1/switchPage) – alternativni korisnik za link servis.
    var storeCodes: [String] = []
    var storeCode = ""
    var scenarioId = "", scenarioKey = ""
    private var thirdUserUsed: String?

    private static func thirdOk(_ o: J) -> Bool {
        Json.s(o, "resultCode") == "1001" || Json.s(o, "result").lowercased() == "succeed"
    }

    private static func thirdMsg(_ o: J) -> String {
        var m = Json.s(o, "message")
        if empty(m) { m = "kod " + Json.s(o, "resultCode") }
        return m
    }

    private func thirdUsers() -> [String] {
        var l: [String] = []
        if !Api.empty(server.thirdUser) { return [server.thirdUser.trimmed] }
        if let u = thirdUserUsed, !Api.empty(u) { l.append(u) }
        if !l.contains(account) { l.append(account) }
        for c in storeCodes where !Api.empty(c) && !l.contains(c) { l.append(c) }
        return l
    }

    func thirdLogin(_ u: String) throws {
        var p = Api.empty(server.thirdPass) ? plainPassword : server.thirdPass
        if server.thirdMd5 { p = Api.md5(p) }
        let b: J = ["username": u, "password": p]
        jsession = nil
        let o = try Api.parse(http(server.thirdBase() + "third/user/v1/login/password", Json.string(b)))
        if !Api.thirdOk(o) { throw AppError.api("Prijava na link servis (\(u)) nije uspela: " + Api.thirdMsg(o)) }
        let d = Json.obj(o, "data")
        let js = Json.s(d, "jsessionid")
        if Api.empty(js) { throw AppError.api("Link servis nije vratio jsessionid") }
        jsession = js
        thirdUserUsed = u
        let sc = Json.s(d, "storeCode")
        if !Api.empty(sc) { storeCode = sc }
    }

    private func thirdPost(_ path: String, _ body: String) throws -> J {
        try Api.parse(http(server.thirdBase() + path + ";jsessionid=" + (jsession ?? ""), body))
    }

    /// Jedan pokusaj; vraca nil ako je uspelo, inace tekst greske.
    private func thirdTry(_ path: String, _ body: [Any]) throws -> String? {
        let o = try thirdPost(path, Json.string(body))
        if !Api.thirdOk(o) { return Api.thirdMsg(o) }
        guard let d = Json.arr(o, "data") else { return nil }
        var err = ""
        for case let x as J in d {
            let rc = Json.s(x, "resultCode")
            if rc == "1001" || Json.s(x, "result").lowercased() == "succeed" { continue }
            var m = Json.s(x, "errorContext")
            if Api.empty(m) { m = Json.s(x, "message") }
            if Api.empty(m) { m = "kod " + rc }
            if !err.isEmpty { err += "\n" }
            let esl = Json.s(x, "eslId")
            err += (Api.empty(esl) ? "" : esl + ": ") + m + (rc.isEmpty ? "" : " (kod \(rc))")
        }
        return err.isEmpty ? nil : err
    }

    /// Poziva third interfejs. Ako ne uspe, pokusava i prijavu sifrom prodavnice (link servis je vezan za prodavnicu).
    func thirdCall(_ path: String, _ body: [Any]) throws {
        var firstErr: String?
        var firstEx: Error?
        for u in thirdUsers() {
            do {
                if jsession == nil || u != thirdUserUsed { try thirdLogin(u) }
                var err: String?
                do {
                    err = try thirdTry(path, body)
                } catch AppError.http(_, _) {
                    try thirdLogin(u)            // sesija istekla
                    err = try thirdTry(path, body)
                }
                guard let e = err else { return }
                if firstErr == nil { firstErr = e }
                let le = e.lowercased()
                if le.contains("item") || le.contains("goods") { break } // greska artikla – drugi nalog ne pomaze
            } catch {
                if firstEx == nil { firstEx = error }
            }
        }
        if let e = firstErr { throw AppError.api(e) }
        if let e = firstEx { throw e }
        throw AppError.api("Link servis nije odgovorio")
    }

    /// Linkuje listu artikala na etiketu (redosled = polja na etiketi).
    func bind(_ esl: String, _ skus: [String], _ tags: [Int]?, _ layoutId: String) throws {
        var a: [Any] = []
        for (i, sku) in skus.enumerated() {
            var o: J = ["goodsSku": sku, "eslId": esl]
            if !Api.empty(storeCode) { o["storeCode"] = storeCode }
            if !Api.empty(layoutId) { o["layoutId"] = layoutId }
            if !Api.empty(scenarioId) { o["scenarioId"] = scenarioId }
            if !Api.empty(scenarioKey) { o["scenarioKey"] = scenarioKey }
            o["itemTag"] = tags != nil && i < tags!.count ? tags![i] : i + 1
            a.append(o)
        }
        try thirdCall(server.bind(), a)
    }

    func unbind(_ esl: String) throws {
        try thirdCall(server.unbind(), [["eslId": esl] as J])
    }
}

/// Verzija iOS-a (citanje UIDevice sa bilo koje niti).
enum UIDeviceVersion {
    static let value: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : "")
    }()
}

/// Poruka greske za korisnika (kao BaseActivity.errMsg).
func errMsg(_ e: Error) -> String {
    if let u = e as? URLError {
        switch u.code {
        case .cannotFindHost, .dnsLookupFailed: return "Server nije pronađen. Proveri adresu i mrežu."
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return "Ne mogu da se povežem sa serverom. Proveri adresu, port i mrežu."
        case .timedOut: return "Server ne odgovara (isteklo vreme)."
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot, .clientCertificateRejected:
            return "SSL greška: " + u.localizedDescription + "\n(U podešavanjima servera možeš uključiti 'Prihvati sve SSL sertifikate'.)"
        default: break
        }
    }
    if let a = e as? AppError, let m = a.errorDescription, !m.isEmpty { return m }
    let m = (e as NSError).localizedDescription
    return m.isEmpty ? String(describing: type(of: e)) : m
}
