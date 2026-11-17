import SwiftUI

/// Toast na dnu ekrana (kao Android Toast).
struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(Capsule().fill(Color(argb: 0xEE323232)))
            .padding(.horizontal, 24)
            .padding(.bottom, 64)
            .allowsHitTesting(false)
    }
}

/// "Molim sačekajte..." (ProgressDialog).
struct BusyView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea()
            HStack(spacing: 22) {
                ProgressView().progressViewStyle(.circular).tint(UI.ACCENT).scaleEffect(1.4)
                Text("Molim sačekajte...").font(.ui(16)).foregroundColor(UI.TEXT)
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).elevation(8))
            .padding(.horizontal, 32)
        }
    }
}

/// Dijalog u Material stilu (AlertDialog).
struct DialogView: View {
    let d: DialogSpec
    @EnvironmentObject var app: AppState

    private func tap(_ b: DialogButton) {
        if b.dismiss { app.closeDialog(d.id) }
        b.action()
    }

    private func btn(_ b: DialogButton) -> some View {
        Button { tap(b) } label: {
            Text(b.title.uppercased()).font(.system(size: 14, weight: .semibold)).kerning(0.6)
                .foregroundColor(UI.ACCENT).padding(.horizontal, 8).frame(minHeight: 40)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture {
                    // kao Android: dodir van dijaloga zatvara (ponasa se kao "Otkaži")
                    if d.cancelable { app.closeDialog(d.id) }
                }
            VStack(alignment: .leading, spacing: 0) {
                if let t = d.title {
                    Text(t).font(.system(size: 20, weight: .semibold)).foregroundColor(UI.TEXT)
                        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, d.message == nil && d.content == nil ? 8 : 0)
                }
                if let m = d.message {
                    ScrollView {
                        Text(m).font(.ui(16)).foregroundColor(UI.SUB).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24).padding(.top, d.title == nil ? 24 : 14).padding(.bottom, 8)
                    }.fixedSize(horizontal: false, vertical: true)
                }
                if let c = d.content { c }
                if !d.buttons.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(d.buttons.filter { $0.kind == .neutral }.enumerated()), id: \.offset) { _, b in btn(b) }
                        Spacer(minLength: 0)
                        ForEach(Array(d.buttons.filter { $0.kind == .negative }.enumerated()), id: \.offset) { _, b in btn(b) }
                        ForEach(Array(d.buttons.filter { $0.kind == .positive }.enumerated()), id: \.offset) { _, b in btn(b) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }
            }
            .frame(maxWidth: 560)
            .background(RoundedRectangle(cornerRadius: d.plain ? 4 : 6).fill(d.plain ? UI.BG : Color.white).elevation(10))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
    }
}

/// Dnevnik komunikacije sa serverom.
struct LogView: View {
    @EnvironmentObject var app: AppState
    let txt = Log.text(15)
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { app.showLog = false }
            VStack(alignment: .leading, spacing: 0) {
                Text("Dnevnik komunikacije").font(.system(size: 20, weight: .semibold)).foregroundColor(UI.TEXT)
                    .padding(.horizontal, 24).padding(.top, 22)
                ScrollView {
                    Text(txt.isEmpty ? "Dnevnik je prazan." : txt)
                        .font(.system(size: 12, design: .monospaced)).foregroundColor(UI.TEXT)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                HStack {
                    Button {
                        UIPasteboard.general.string = Log.text(60)
                        app.showToast("Dnevnik kopiran – možeš ga nalepiti u poruku")
                    } label: { dlgBtn("Kopiraj") }
                    Spacer()
                    Button { app.showLog = false } label: { dlgBtn("Zatvori") }
                }.padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).elevation(10))
            .padding(.horizontal, 24).padding(.vertical, 40)
        }
    }

    private func dlgBtn(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 14, weight: .semibold)).kerning(0.6)
            .foregroundColor(UI.ACCENT).padding(.horizontal, 8).frame(minHeight: 40)
    }
}
