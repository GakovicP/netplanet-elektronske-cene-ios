import Foundation

/// JSON objekat kao recnik (isto kao org.json.JSONObject u Android verziji).
typealias J = [String: Any]

enum Json {
    /// Bezbedno citanje vrednosti kao string (JSON null -> "").
    static func s(_ o: J?, _ k: String) -> String {
        guard let o = o, let v = o[k] else { return "" }
        return str(v)
    }

    static func str(_ v: Any?) -> String {
        guard let v = v else { return "" }
        if v is NSNull { return "" }
        if let s = v as? String { return s == "null" ? "" : s }
        if let n = v as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            return n.stringValue
        }
        if JSONSerialization.isValidJSONObject(v),
           let d = try? JSONSerialization.data(withJSONObject: v), let s = String(data: d, encoding: .utf8) { return s }
        return "\(v)"
    }

    static func i(_ o: J?, _ k: String, _ def: Int) -> Int {
        let v = s(o, k)
        if v.isEmpty { return def }
        if let d = Double(v.trimmingCharacters(in: .whitespaces)) { return Int(d) }
        return def
    }

    static func bool(_ o: J?, _ k: String, _ def: Bool) -> Bool {
        guard let v = o?[k] else { return def }
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.boolValue }
        if let s = v as? String { return s.lowercased() == "true" }
        return def
    }

    static func obj(_ o: J?, _ k: String) -> J? { o?[k] as? J }
    static func arr(_ o: J?, _ k: String) -> [Any]? { o?[k] as? [Any] }

    static func records(_ data: Any?) -> [J] {
        if let a = data as? [Any] { return a.compactMap { $0 as? J } }
        if let o = data as? J, let a = o["records"] as? [Any] { return a.compactMap { $0 as? J } }
        return []
    }

    static func parse(_ text: String) -> Any? {
        guard let d = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
    }

    static func string(_ o: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: o, options: [.withoutEscapingSlashes]),
              let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }

    /// Broj (Long) ako se moze parsirati, inace string – kao Session.num u Android verziji.
    static func num(_ v: String) -> Any {
        if let l = Int64(v.trimmingCharacters(in: .whitespaces)) { return NSNumber(value: l) }
        return v
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    func replacingRegex(_ pattern: String, with tpl: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return self }
        return re.stringByReplacingMatches(in: self, range: NSRange(startIndex..., in: self), withTemplate: tpl)
    }
}
