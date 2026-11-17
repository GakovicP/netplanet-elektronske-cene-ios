import SwiftUI

/// Politika privatnosti, prikazana u aplikaciji.
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array((L.en ? L.PRIVACY_EN : L.PRIVACY_SR).enumerated()), id: \.offset) { _, line in
                    if line.hasPrefix("# ") {
                        Text(String(line.dropFirst(2))).font(.ui(16, true)).foregroundColor(UI.ACCENT).padding(.top, 10)
                    } else {
                        Text(line).font(.ui(14)).foregroundColor(UI.TEXT).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.top, 4)
        }.frame(maxHeight: 460)
    }
}

/// Sadrzaj dijaloga Podrska: telefoni (poziv) i mail (nova poruka).
struct SupportView: View {
    let sp: J
    @EnvironmentObject var app: AppState

    static func pair(_ o: Any, _ valKey: String) -> (String, String) {
        if let j = o as? J {
            let v = Json.s(j, valKey)
            return (Json.s(j, "name"), v.isEmpty ? Json.s(j, "value") : v)
        }
        return ("", Json.str(o))
    }

    static func items(_ sp: J, _ key: String, _ valKey: String) -> [(String, String)] {
        ((sp[key] as? [Any]) ?? []).map { pair($0, valKey) }.filter { !$0.1.trimmed.isEmpty }
    }

    static func has(_ sp: J) -> Bool {
        !items(sp, "phones", "number").isEmpty || !items(sp, "emails", "email").isEmpty
    }

    var body: some View {
        let phones = SupportView.items(sp, "phones", "number")
        let emails = SupportView.items(sp, "emails", "email")
        let note = Json.s(sp, "note")
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !note.isEmpty { T(note, 14, UI.SUB) }
                if !phones.isEmpty {
                    T("Telefon", 15, UI.TEXT, true).padding(.top, 4)
                    ForEach(Array(phones.enumerated()), id: \.offset) { _, x in
                        row(x.0, x.1, "tel:" + x.1.filter { "0123456789+".contains($0) })
                    }
                }
                if !emails.isEmpty {
                    T("E-mail", 15, UI.TEXT, true).padding(.top, 6)
                    ForEach(Array(emails.enumerated()), id: \.offset) { _, x in
                        row(x.0, x.1, "mailto:" + x.1 + "?subject=" + ((L.en ? "Elektronske cene – support" : "Elektronske cene – podrška").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))
                    }
                }
                Button { app.showPrivacy() } label: {
                    Text(L.t("Politika privatnosti")).font(.ui(14)).underline().foregroundColor(UI.SUB)
                }.buttonStyle(.plain).padding(.top, 10)
            }
            .padding(.horizontal, 24).padding(.top, 4)
        }.frame(maxHeight: 420)
    }

    private func row(_ label: String, _ value: String, _ link: String) -> some View {
        Button {
            if let u = URL(string: link) { UIApplication.shared.open(u) }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                if !label.isEmpty { T(label, 13, UI.SUB) }
                T(value, 17, UI.PRIMARY, true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(UI.SOFT))
        }.buttonStyle(.plain)
    }
}
