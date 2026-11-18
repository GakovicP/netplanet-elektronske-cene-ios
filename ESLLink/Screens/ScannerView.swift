import SwiftUI
import AVFoundation
import Vision

/// Skeniranje barkoda kamerom (AVFoundation; isti formati kao ZXing u Android verziji).
final class ScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var done = false
    private let queue = DispatchQueue(label: "esl.camera")
    private let visionQueue = DispatchQueue(label: "esl.vision")
    private var visionBusy = false
    private var visionSymbologies: [VNBarcodeSymbology] = []
    var onCode: ((String) -> Void)?
    var onFail: (() -> Void)?
    @Published var zoomLabel = "1.0×"
    @Published var torch = false
    /// AUTO zum: prolazi kroz lestvicu 1.0×–3.0× dok se ne procita kod (pref ui/autoZoom, podrazumevano ukljuceno)
    @Published var autoZoom: Bool = Prefs.ui.object(forKey: "autoZoom") as? Bool ?? true
    /// trenutni zum u procentima (za slajder)
    @Published var pct: Double = Double(Prefs.ui.integer(forKey: "zoom"))
    private var ladder: [CGFloat] = []
    private var ladderIdx = 0
    private var autoTimer: Timer?

    /// Najveci zum koji nudimo (ekvivalent getMaxZoom na Androidu).
    private var maxZoom: CGFloat {
        guard let d = device else { return 1 }
        return min(d.activeFormat.videoMaxZoomFactor, 10)
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { ok ? self.configure() : self.onFail?() }
            }
        default: onFail?()
        }
    }

    private func configure() {
        queue.async {
            guard let d = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: d) else {
                DispatchQueue.main.async { self.onFail?() }
                return
            }
            self.device = d
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.hd1920x1080) { self.session.sessionPreset = .hd1920x1080 }
            else if self.session.canSetSessionPreset(.hd1280x720) { self.session.sessionPreset = .hd1280x720 }
            if self.session.canAddInput(input) { self.session.addInput(input) }
            let readQr = Prefs.ui.bool(forKey: "readQr")
            // motor "vision": Apple Vision citanje svakog kadra; ako ne moze, koristi se AVFoundation
            var usingVision = false
            if scanEngine() == "vision" {
                let vo = AVCaptureVideoDataOutput()
                vo.alwaysDiscardsLateVideoFrames = true
                if self.session.canAddOutput(vo) {
                    self.session.addOutput(vo)
                    vo.setSampleBufferDelegate(self, queue: self.visionQueue)
                    var sy: [VNBarcodeSymbology] = [.code128, .code39, .code39Checksum, .code93, .ean13, .ean8, .upce, .i2of5, .itf14]
                    if #available(iOS 15.0, *) { sy.append(.codabar) }
                    if readQr { sy += [.qr, .dataMatrix, .pdf417] }
                    self.visionSymbologies = sy
                    usingVision = true
                }
            }
            if usingVision {
                self.session.commitConfiguration()
                self.finishConfigure(d)
                return
            }
            let out = AVCaptureMetadataOutput()
            if self.session.canAddOutput(out) { self.session.addOutput(out) }
            out.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            var types: [AVMetadataObject.ObjectType] = [.code128, .code39, .code39Mod43, .code93, .ean13, .ean8, .upce, .interleaved2of5, .itf14]
            if #available(iOS 15.4, *) { types.append(.codabar) }
            // QR i ostali 2D kodovi samo ako je ukljuceno u podesavanjima (podrazumevano iskljuceno)
            if readQr { types += [.qr, .dataMatrix, .pdf417] }
            out.metadataObjectTypes = types.filter { out.availableMetadataObjectTypes.contains($0) }
            self.session.commitConfiguration()
            self.finishConfigure(d)
        }
    }

    private func finishConfigure(_ d: AVCaptureDevice) {
            if let _ = try? d.lockForConfiguration() {
                if d.isFocusModeSupported(.continuousAutoFocus) { d.focusMode = .continuousAutoFocus }
                if d.isAutoFocusRangeRestrictionSupported { d.autoFocusRangeRestriction = .near }
                d.unlockForConfiguration()
            }
            self.session.startRunning()
            let pct = Prefs.ui.integer(forKey: "zoom")
            DispatchQueue.main.async {
                self.buildLadder()
                if self.autoZoom { self.startAuto() } else { self.setZoomPct(pct) }
            }
    }

    func stop() {
        autoTimer?.invalidate(); autoTimer = nil
        if torch { toggleTorch() }
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    /// Zum u procentima (0-100) od maksimalnog zuma kamere.
    func setZoomPct(_ pct0: Int) {
        let pct = max(0, min(100, pct0))
        Prefs.ui.set(pct, forKey: "zoom")
        self.pct = Double(pct)
        guard device != nil else { return }
        applyZoom(1 + (maxZoom - 1) * CGFloat(pct) / 100)
    }

    /// Rucni zum (slajder, −/+, pinch): iskljucuje AUTO.
    func manualZoomPct(_ pct: Int) {
        if autoZoom { setAuto(false) }
        setZoomPct(pct)
    }

    private func applyZoom(_ z0: CGFloat) {
        guard let d = device else { return }
        let z = max(1, min(z0, d.activeFormat.videoMaxZoomFactor))
        if let _ = try? d.lockForConfiguration() {
            d.videoZoomFactor = z
            d.unlockForConfiguration()
        }
        zoomLabel = String(format: "%.1f×", Double(z))
    }

    /// Lestvica 1.0×, 1.5×, 2.0×, 2.5×, 3.0× (u granicama kamere, bez duplikata).
    private func buildLadder() {
        var l: [CGFloat] = []
        for r in [1.0, 1.5, 2.0, 2.5, 3.0] as [CGFloat] {
            let z = min(r, maxZoom)
            if l.last.map({ abs($0 - z) < 0.01 }) != true { l.append(z) }
        }
        ladder = l.isEmpty ? [1] : l
    }

    func setAuto(_ on: Bool) {
        autoZoom = on
        Prefs.ui.set(on, forKey: "autoZoom")
        if on { startAuto() } else { autoTimer?.invalidate(); autoTimer = nil }
    }

    private func startAuto() {
        guard device != nil else { return }
        if ladder.isEmpty { buildLadder() }
        let saved = Prefs.ui.object(forKey: "autoZoomIdx") as? Int
        ladderIdx = min(ladder.count - 1, max(0, saved ?? 1))
        autoStep(advance: false)
        autoTimer?.invalidate()
        autoTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { [weak self] _ in
            self?.autoStep(advance: true)
        }
    }

    private func autoStep(advance: Bool) {
        if done || !autoZoom { return }
        if advance { ladderIdx = (ladderIdx + 1) % ladder.count }
        let z = ladder[ladderIdx]
        applyZoom(z)
        pct = maxZoom > 1 ? Double((z - 1) / (maxZoom - 1) * 100) : 0
        // ponovo fokusiraj posle promene zuma
        if let d = device, let _ = try? d.lockForConfiguration() {
            if d.isFocusPointOfInterestSupported { d.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) }
            if d.isFocusModeSupported(.autoFocus) { d.focusMode = .autoFocus }
            if d.isFocusModeSupported(.continuousAutoFocus) { d.focusMode = .continuousAutoFocus }
            d.unlockForConfiguration()
        }
    }

    /// Kod procitan: u AUTO rezimu zapamti zum koji je procitao kod.
    private func read(_ v: String) {
        autoTimer?.invalidate(); autoTimer = nil
        if autoZoom { Prefs.ui.set(ladderIdx, forKey: "autoZoomIdx") }
        onCode?(v)
    }

    func toggleTorch() {
        guard let d = device, d.hasTorch, let _ = try? d.lockForConfiguration() else { return }
        torch.toggle()
        d.torchMode = torch ? .on : .off
        d.unlockForConfiguration()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objs: [AVMetadataObject], from connection: AVCaptureConnection) {
        if done { return }
        guard let o = objs.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              var v = o.stringValue?.trimmed, !v.isEmpty else { return }
        // ZXing vraca UPC-A kao 12 cifara; iOS ga cita kao EAN-13 sa vodecom nulom
        if o.type == .ean13 && v.count == 13 && v.hasPrefix("0") { v.removeFirst() }
        done = true
        read(v)
    }

    /// Vision motor: trazi barkod u kadru (poziva se na visionQueue).
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if done || visionBusy { return }
        guard let px = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        visionBusy = true
        defer { visionBusy = false }
        let req = VNDetectBarcodesRequest()
        req.symbologies = visionSymbologies
        try? VNImageRequestHandler(cvPixelBuffer: px, orientation: .right, options: [:]).perform([req])
        guard let r = (req.results ?? []).first(where: { !($0.payloadStringValue ?? "").trimmed.isEmpty }),
              var v = r.payloadStringValue?.trimmed else { return }
        if r.symbology == .ean13 && v.count == 13 && v.hasPrefix("0") { v.removeFirst() }
        DispatchQueue.main.async {
            if self.done { return }
            self.done = true
            self.read(v)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    final class PV: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var pl: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    func makeUIView(context: Context) -> PV {
        let v = PV()
        v.backgroundColor = .black
        v.pl.session = session
        v.pl.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PV, context: Context) {}
}

struct ScannerView: View {
    let done: (String?) -> Void
    @StateObject private var c = ScannerController()
    @State private var pinchBase: Double?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: c.session).ignoresSafeArea()
                .gesture(MagnificationGesture()
                    .onChanged { s in
                        let base = pinchBase ?? c.pct
                        if pinchBase == nil { pinchBase = c.pct }
                        c.manualZoomPct(Int(max(0, min(100, base + (Double(s) - 1) * 120))))
                    }
                    .onEnded { _ in pinchBase = nil })

            RoundedRectangle(cornerRadius: 12).stroke(UI.ACCENT, lineWidth: 3)
                .frame(width: 300, height: 180)
                .allowsHitTesting(false)

            VStack {
                Text(L.t("Usmeri kameru ka barkodu")).font(.ui(18, true)).foregroundColor(.white)
                    .shadow(color: .black, radius: 4)
                    .padding(.top, 48)
                Spacer()
                HStack(spacing: 0) {
                    zoomBtn("−") { c.manualZoomPct(Int(max(0, c.pct - 10))) }
                    Slider(value: Binding(get: { c.pct }, set: { c.manualZoomPct(Int($0)) }), in: 0...100)
                        .tint(UI.ACCENT)
                    Text(c.zoomLabel).font(.ui(14, true)).foregroundColor(.white).frame(minWidth: 44)
                    zoomBtn("+") { c.manualZoomPct(Int(min(100, c.pct + 10))) }
                    Button { c.setAuto(!c.autoZoom) } label: {
                        Text("AUTO").font(.ui(13, true))
                            .foregroundColor(c.autoZoom ? .white : Color.white.opacity(0.55))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(c.autoZoom ? UI.ACCENT : Color.clear))
                    }
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.53)))
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                HStack(spacing: 16) {
                    PrimaryButton(title: "Svetlo", color: Color(argb: 0xAA333333)) { c.toggleTorch() }
                    PrimaryButton(title: "Odustani", color: Color(argb: 0xCCC62828)) { finish(nil) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            c.onCode = { code in finish(code) }
            c.onFail = { finish(nil) }
            c.start()
        }
        .onDisappear { c.stop() }
    }

    private func finish(_ code: String?) {
        c.stop()
        done(code)
    }

    private func zoomBtn(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.system(size: 22)).foregroundColor(.white).frame(width: 44, height: 44)
        }
    }
}
