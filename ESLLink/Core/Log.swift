import Foundation

/// Dnevnik poslednjih poziva prema serveru (za dijagnostiku).
enum Log {
    struct Entry { var time = "", url = "", req = "", resp = ""; var code = 0 }

    private static var list: [Entry] = []
    private static let lock = NSLock()

    private static func mask(_ s: String) -> String {
        s.replacingRegex("(\"password\"\\s*:\\s*\")[^\"]*\"", with: "$1***\"")
    }

    private static func cut(_ s: String, _ n: Int) -> String {
        s.count > n ? String(s.prefix(n)) + " …(\(s.count) znakova)" : s
    }

    static func add(_ url: String, _ req: String, _ code: Int, _ resp: String) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        var e = Entry()
        e.time = f.string(from: Date())
        e.url = url.replacingRegex("jsessionid=[^/?&]*", with: "jsessionid=…")
        e.req = cut(mask(req), 1500)
        e.code = code
        e.resp = cut(resp, url.contains("/third/") ? 3000 : 400)
        lock.lock(); defer { lock.unlock() }
        list.insert(e, at: 0)
        while list.count > 60 { list.removeLast() }
    }

    static func text(_ max: Int) -> String {
        lock.lock(); defer { lock.unlock() }
        // prvo pozivi link servisa (najvazniji za dijagnostiku), pa ostali
        let ord = list.filter { $0.url.contains("/third/") } + list.filter { !$0.url.contains("/third/") }
        var sb = ""
        for (n, e) in ord.enumerated() {
            if n >= max { break }
            sb += "\(e.time)  HTTP \(e.code)\n\(e.url)\n→ \(e.req)\n← \(e.resp)\n\n"
        }
        return sb
    }

    static func clear() { lock.lock(); list.removeAll(); lock.unlock() }
}
