import ScreenSaver
import QuartzCore
import AppKit

/// Saved options (System Settings > Screen Saver > Bauhaus Clock > Options…)
enum Prefs {
    static let defaults: ScreenSaverDefaults? = ScreenSaverDefaults(forModuleWithName: "net.clogwog.BauhausClock")
    static func register() { defaults?.register(defaults: ["lume": false, "autoNightLume": true]) }
    static var lume: Bool { get { register(); return defaults?.bool(forKey: "lume") ?? false } set { defaults?.set(newValue, forKey: "lume"); defaults?.synchronize() } }
    static var autoNightLume: Bool { get { register(); return defaults?.bool(forKey: "autoNightLume") ?? true } set { defaults?.set(newValue, forKey: "autoNightLume"); defaults?.synchronize() } }
}

@objc(BauhausClockView)
final class BauhausClockView: ScreenSaverView {
    private var sim: BounceSim?
    private var last: CFTimeInterval = 0
    private var sheet: NSWindow?
    private var lumeBox: NSButton?, autoBox: NSButton?
    override init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview); setRate() }
    required init?(coder: NSCoder) { super.init(coder: coder); setRate() }
    private func setRate() {
        let fps = (window?.screen ?? NSScreen.main)?.maximumFramesPerSecond ?? 60
        animationTimeInterval = isPreview ? 1.0/30 : 1.0 / Double(max(60, min(fps, 120)))
        wantsLayer = true; layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); setRate() }
    override func startAnimation() { super.startAnimation(); setRate(); last = 0; sim = nil }
    override func draw(_ rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if sim == nil || sim!.size != bounds.size { sim = BounceSim(size: bounds.size); applyPrefs() }
        sim!.draw(ctx, date: Date())
    }
    private func applyPrefs() { sim?.prefLume = Prefs.lume; sim?.autoNightLume = Prefs.autoNightLume }
    override func animateOneFrame() {
        let now = CACurrentMediaTime()
        if last > 0, let s = sim { s.step(now - last) }
        last = now; needsDisplay = true
    }

    // ---- Options sheet ----
    override var hasConfigureSheet: Bool { true }
    override var configureSheet: NSWindow? {
        if sheet == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 170), styleMask: [.titled], backing: .buffered, defer: false)
            w.title = "Bauhaus Clock"
            let v = w.contentView!
            let title = NSTextField(labelWithString: "Bauhaus Clock options"); title.font = .boldSystemFont(ofSize: 13); title.frame = NSRect(x: 20, y: 130, width: 340, height: 20)
            let l = NSButton(checkboxWithTitle: "Lume: glowing cyan markers and hands", target: nil, action: nil); l.frame = NSRect(x: 20, y: 98, width: 340, height: 22)
            let a = NSButton(checkboxWithTitle: "Turn lume on automatically at night (10pm–7am, after 3 min)", target: nil, action: nil); a.frame = NSRect(x: 20, y: 70, width: 350, height: 22)
            let ok = NSButton(title: "OK", target: self, action: #selector(closeSheet(_:))); ok.keyEquivalent = "\r"; ok.frame = NSRect(x: 280, y: 16, width: 80, height: 30); ok.bezelStyle = .rounded
            let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelSheet(_:))); cancel.keyEquivalent = "\u{1b}"; cancel.frame = NSRect(x: 190, y: 16, width: 90, height: 30); cancel.bezelStyle = .rounded
            [title, l, a, ok, cancel].forEach { v.addSubview($0) }
            lumeBox = l; autoBox = a; sheet = w
        }
        lumeBox?.state = Prefs.lume ? .on : .off
        autoBox?.state = Prefs.autoNightLume ? .on : .off
        return sheet
    }
    @objc private func closeSheet(_ sender: Any?) {
        Prefs.lume = lumeBox?.state == .on; Prefs.autoNightLume = autoBox?.state == .on; applyPrefs(); endSheet()
    }
    @objc private func cancelSheet(_ sender: Any?) { endSheet() }
    private func endSheet() {
        guard let s = sheet else { return }
        if let parent = s.sheetParent { parent.endSheet(s) } else { s.orderOut(nil) }
    }
}
