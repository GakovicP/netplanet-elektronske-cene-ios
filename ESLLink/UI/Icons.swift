import SwiftUI

/// Vektorske ikonice iz Android verzije (isti pathData, viewport 24x24).
enum Icon: String {
    case cart
    case chart
    case check
    case error
    case eye
    case eyeOff
    case info
    case link
    case linkOff
    case list
    case logout
    case multi
    case scan
    case search
    case server
    case tag
    case tune
    case wifi

    var pathData: String {
        switch self {
        case .cart: return "M7,18c-1.1,0 -1.99,0.9 -1.99,2S5.9,22 7,22s2,-0.9 2,-2 -0.9,-2 -2,-2zM1,2v2h2l3.6,7.59 -1.35,2.45c-0.16,0.28 -0.25,0.61 -0.25,0.96 0,1.1 0.9,2 2,2h12v-2H7.42c-0.14,0 -0.25,-0.11 -0.25,-0.25l0.03,-0.12 0.9,-1.63h7.45c0.75,0 1.41,-0.41 1.75,-1.03l3.58,-6.49L20.25,4H5.21l-0.94,-2H1zM17,18c-1.1,0 -1.99,0.9 -1.99,2s0.89,2 1.99,2 2,-0.9 2,-2 -0.9,-2 -2,-2z"
        case .chart: return "M3.5,18.49l6,-6.01 4,4L22,6.92l-1.41,-1.41 -7.09,7.97 -4,-4L2,16.99z"
        case .check: return "M9,16.17L4.83,12l-1.42,1.41L9,19 21,7l-1.41,-1.41z"
        case .error: return "M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM13,17h-2v-2h2v2zM13,13h-2V7h2v6z"
        case .eye: return "M12,4.5C7,4.5 2.73,7.61 1,12c1.73,4.39 6,7.5 11,7.5s9.27,-3.11 11,-7.5c-1.73,-4.39 -6,-7.5 -11,-7.5zM12,17c-2.76,0 -5,-2.24 -5,-5s2.24,-5 5,-5 5,2.24 5,5 -2.24,5 -5,5zM12,9c-1.66,0 -3,1.34 -3,3s1.34,3 3,3 3,-1.34 3,-3 -1.34,-3 -3,-3z"
        case .eyeOff: return "M12,7c2.76,0 5,2.24 5,5 0,0.65 -0.13,1.26 -0.36,1.83l2.92,2.92c1.51,-1.26 2.7,-2.89 3.43,-4.75 -1.73,-4.39 -6,-7.5 -11,-7.5 -1.4,0 -2.74,0.25 -3.98,0.7l2.16,2.16C10.74,7.13 11.35,7 12,7zM2,4.27l2.28,2.28 0.46,0.46C3.08,8.3 1.78,10.02 1,12c1.73,4.39 6,7.5 11,7.5 1.55,0 3.03,-0.3 4.38,-0.84l0.42,0.42L19.73,22 21,20.73 3.27,3 2,4.27zM7.53,9.8l1.55,1.55c-0.05,0.21 -0.08,0.43 -0.08,0.65 0,1.66 1.34,3 3,3 0.22,0 0.44,-0.03 0.65,-0.08l1.55,1.55c-0.67,0.33 -1.41,0.53 -2.2,0.53 -2.76,0 -5,-2.24 -5,-5 0,-0.79 0.2,-1.53 0.53,-2.2zM11.84,9.02l3.15,3.15 0.02,-0.16c0,-1.66 -1.34,-3 -3,-3l-0.17,0.01z"
        case .info: return "M11,7h2v2h-2zM11,11h2v6h-2zM12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM12,20c-4.41,0 -8,-3.59 -8,-8s3.59,-8 8,-8 8,3.59 8,8 -3.59,8 -8,8z"
        case .link: return "M3.9,12c0,-1.71 1.39,-3.1 3.1,-3.1h4V7H7c-2.76,0 -5,2.24 -5,5s2.24,5 5,5h4v-1.9H7c-1.71,0 -3.1,-1.39 -3.1,-3.1zM8,13h8v-2H8v2zM17,7h-4v1.9h4c1.71,0 3.1,1.39 3.1,3.1s-1.39,3.1 -3.1,3.1h-4V17h4c2.76,0 5,-2.24 5,-5s-2.24,-5 -5,-5z"
        case .linkOff: return "M17,7h-4v1.9h4c1.71,0 3.1,1.39 3.1,3.1 0,1.43 -0.98,2.63 -2.31,2.98l1.46,1.46C20.88,15.61 22,13.95 22,12c0,-2.76 -2.24,-5 -5,-5zM16,11h-2.19l2,2H16zM2,4.27l3.11,3.11C3.29,8.12 2,9.91 2,12c0,2.76 2.24,5 5,5h4v-1.9H7c-1.71,0 -3.1,-1.39 -3.1,-3.1 0,-1.59 1.21,-2.9 2.76,-3.07L8.73,11H8v2h2.73L13,15.27V17h1.73l4.01,4L20,19.74 3.27,3 2,4.27z"
        case .list: return "M3,13h2v-2H3v2zM3,17h2v-2H3v2zM3,9h2V7H3v2zM7,13h14v-2H7v2zM7,17h14v-2H7v2zM7,7v2h14V7H7z"
        case .logout: return "M10.09,15.59L11.5,17l5,-5 -5,-5 -1.41,1.41L12.67,11H3v2h9.67l-2.58,2.59zM19,3H5c-1.11,0 -2,0.9 -2,2v4h2V5h14v14H5v-4H3v4c0,1.1 0.89,2 2,2h14c1.1,0 2,-0.9 2,-2V5c0,-1.1 -0.9,-2 -2,-2z"
        case .multi: return "M2,5v14h20V5H2zM4,7h7v10H4V7zM13,7h7v10h-7V7z"
        case .scan: return "M3,3h6v2H5v4H3V3zM15,3h6v6h-2V5h-4V3zM3,15h2v4h4v2H3V15zM19,15h2v6h-6v-2h4V15zM6,11h12v2H6z"
        case .search: return "M15.5,14h-0.79l-0.28,-0.27C15.41,12.59 16,11.11 16,9.5 16,5.91 13.09,3 9.5,3S3,5.91 3,9.5 5.91,16 9.5,16c1.61,0 3.09,-0.59 4.23,-1.57l0.27,0.28v0.79l5,4.99L20.49,19l-4.99,-5zM9.5,14C7.01,14 5,11.99 5,9.5S7.01,5 9.5,5 14,7.01 14,9.5 11.99,14 9.5,14z"
        case .server: return "M4,3h16v6H4V3zM6,5v2h2V5H6zM4,11h16v6H4v-6zM6,13v2h2v-2H6zM8,19h8v2H8z"
        case .tag: return "M2,5v14h20V5H2zM4,7h16v10H4V7zM6,9h7v2H6zM6,12h4v2H6zM14,11h4v4h-4z"
        case .tune: return "M3,17v2h6v-2H3zM3,5v2h10V5H3zM13,21v-2h8v-2h-8v-2h-2v6h2zM7,9v2H3v2h4v2h2V9H7zM21,13v-2H11v2h10zM15,9h2V7h4V5h-4V3h-2v6z"
        case .wifi: return "M1,9l2,2c4.97,-4.97 13.03,-4.97 18,0l2,-2C16.93,2.93 7.08,2.93 1,9zM9,17l3,3 3,-3c-1.65,-1.66 -4.34,-1.66 -6,0zM5,13l2,2c2.76,-2.76 7.24,-2.76 10,0l2,-2C15.14,9.14 8.87,9.14 5,13z"
        }
    }
}


/// Parser Android/SVG pathData (M L H V C S Q T Z, apsolutno i relativno) u SwiftUI Path, viewport 24x24.
enum VectorPath {
    private static var cache: [String: Path] = [:]

    static func path(_ d: String) -> Path {
        if let p = cache[d] { return p }
        let p = parse(d)
        cache[d] = p
        return p
    }

    private static func tokens(_ d: String) -> [Any] {
        var out: [Any] = []
        let chars = Array(d)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isLetter && c != "e" && c != "E" { out.append(c); i += 1; continue }
            if c == "-" || c == "+" || c == "." || c.isNumber {
                var s = String(c)
                var dot = c == "."
                i += 1
                while i < chars.count {
                    let x = chars[i]
                    if x.isNumber { s.append(x) }
                    else if x == "." && !dot { dot = true; s.append(x) }
                    else if (x == "e" || x == "E") { s.append(x); if i + 1 < chars.count, chars[i + 1] == "-" || chars[i + 1] == "+" { i += 1; s.append(chars[i]) } }
                    else { break }
                    i += 1
                }
                out.append(Double(s) ?? 0)
                continue
            }
            i += 1
        }
        return out
    }

    private static func parse(_ d: String) -> Path {
        var p = Path()
        let t = tokens(d)
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl = CGPoint.zero
        var lastCmd: Character = " "
        func num() -> CGFloat { guard i < t.count else { return 0 }; let v = t[i] as? Double ?? 0; i += 1; return CGFloat(v) }
        func hasNum() -> Bool { i < t.count && t[i] is Double }
        while i < t.count {
            if let c = t[i] as? Character { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            let base = rel ? cur : .zero
            switch cmd.uppercased().first! {
            case "M":
                let pt = CGPoint(x: base.x + num(), y: base.y + num())
                p.move(to: pt); cur = pt; start = pt
                cmd = rel ? "l" : "L"   // dodatni parovi su linije
                lastCmd = "M"; continue
            case "L":
                let pt = CGPoint(x: base.x + num(), y: base.y + num())
                p.addLine(to: pt); cur = pt
            case "H":
                let x = (rel ? cur.x : 0) + num()
                cur = CGPoint(x: x, y: cur.y); p.addLine(to: cur)
            case "V":
                let y = (rel ? cur.y : 0) + num()
                cur = CGPoint(x: cur.x, y: y); p.addLine(to: cur)
            case "C":
                let c1 = CGPoint(x: base.x + num(), y: base.y + num())
                let c2 = CGPoint(x: base.x + num(), y: base.y + num())
                let e = CGPoint(x: base.x + num(), y: base.y + num())
                p.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
                lastCmd = "C"; continue
            case "S":
                let c1 = (lastCmd == "C") ? CGPoint(x: 2 * cur.x - lastCtrl.x, y: 2 * cur.y - lastCtrl.y) : cur
                let c2 = CGPoint(x: base.x + num(), y: base.y + num())
                let e = CGPoint(x: base.x + num(), y: base.y + num())
                p.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
                lastCmd = "C"; continue
            case "Q":
                let c1 = CGPoint(x: base.x + num(), y: base.y + num())
                let e = CGPoint(x: base.x + num(), y: base.y + num())
                p.addQuadCurve(to: e, control: c1); lastCtrl = c1; cur = e
                lastCmd = "Q"; continue
            case "T":
                let c1 = (lastCmd == "Q") ? CGPoint(x: 2 * cur.x - lastCtrl.x, y: 2 * cur.y - lastCtrl.y) : cur
                let e = CGPoint(x: base.x + num(), y: base.y + num())
                p.addQuadCurve(to: e, control: c1); lastCtrl = c1; cur = e
                lastCmd = "Q"; continue
            case "Z":
                p.closeSubpath(); cur = start
                lastCmd = "Z"
                if hasNum() { cmd = "L" }
                continue
            default:
                i += 1
            }
            lastCmd = cmd.uppercased().first!
            if !hasNum() && i < t.count && !(t[i] is Character) { i += 1 }
        }
        return p
    }
}

struct IconShape: Shape {
    let icon: Icon
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        return VectorPath.path(icon.pathData)
            .applying(CGAffineTransform(scaleX: s, y: s))
            .offsetBy(dx: rect.minX + (rect.width - 24 * s) / 2, dy: rect.minY + (rect.height - 24 * s) / 2)
    }
}

/// Ikonica obojena jednom bojom (kao setColorFilter / setTint).
struct IconView: View {
    let icon: Icon
    let color: Color
    var body: some View { IconShape(icon: icon).fill(color) }
}
