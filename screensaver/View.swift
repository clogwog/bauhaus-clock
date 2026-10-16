import ScreenSaver
import QuartzCore
import AppKit

/// Saved options (System Settings > Screen Saver > Bauhaus Clock > Options…)
enum Prefs {
    static let defaults: ScreenSaverDefaults? = ScreenSaverDefaults(forModuleWithName: "net.clogwog.BauhausClock")
    static func register() { defaults?.register(defaults: ["lume": false, "autoNightLume": true, "dial": "Noir", "movement": "Digital", "seconds": true,
        "layout": "Classic", "bounce": true, "explode": true, "cycleDials": true, "nightDim": true, "size": "2/3"]) }
    static func bool(_ k: String) -> Bool { register(); return defaults?.bool(forKey: k) ?? false }
    static func str(_ k: String) -> String { register(); return defaults?.string(forKey: k) ?? "" }
    static func set(_ k: String, _ v: Any) { defaults?.set(v, forKey: k) }
    static func save() { defaults?.synchronize() }
    static var lume: Bool { bool("lume") }
    static var autoNightLume: Bool { bool("autoNightLume") }
}
let SIZE_OPTIONS: [(String, CGFloat)] = [("2/3", 3), ("1/2", 4), ("1/3", 6)]

@objc(BauhausClockView)
final class BauhausClockView: ScreenSaverView {
    private var sim: BounceSim?
    private var last: CFTimeInterval = 0
    private var sheet: NSWindow?
    private var boxes: [String: NSButton] = [:]
    private var pops: [String: NSPopUpButton] = [:]
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
        if sim == nil || sim!.size != bounds.size { sim = BounceSim(size: bounds.size); applyPrefs(newSim: true) }
        sim!.draw(ctx, date: Date())
    }
    private func applyPrefs(newSim: Bool = false) {
        guard let s = sim else { return }
        s.prefLume = Prefs.lume; s.autoNightLume = Prefs.autoNightLume
        s.bounce = Prefs.bool("bounce"); s.explodeOn = Prefs.bool("explode"); s.cycleDials = Prefs.bool("cycleDials"); s.nightDim = Prefs.bool("nightDim")
        let div = SIZE_OPTIONS.first { $0.0 == Prefs.str("size") }?.1 ?? 3
        if s.sizeDiv != div { s.sizeDiv = div; s.respawn(newPalette: false) }
        s.pal = paletteIndex(Prefs.str("dial"))
        MOVEMENT = Prefs.str("movement"); SHOW_SECONDS = Prefs.bool("seconds"); COMPACT = Prefs.str("layout") == "Compact"
    }
    override func animateOneFrame() {
        let now = CACurrentMediaTime()
        if last > 0, let s = sim { s.step(now - last) }
        last = now; needsDisplay = true
    }

    // ---- Options sheet ----
    override var hasConfigureSheet: Bool { true }
    override var configureSheet: NSWindow? {
        if sheet == nil { sheet = BauhausClockView.makeSheet(target: self, boxes: &boxes, pops: &pops) }
        for (k, b) in boxes { b.state = Prefs.bool(k) ? .on : .off }
        for (k, p) in pops { let t = Prefs.str(k); p.selectItem(withTitle: k == "size" ? t + " of screen height" : t) }
        return sheet
    }
    static func makeSheet(target: AnyObject?, boxes: inout [String: NSButton], pops: inout [String: NSPopUpButton]) -> NSWindow {
        let H: CGFloat = 470
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: H), styleMask: [.titled], backing: .buffered, defer: false)
        w.title = "Bauhaus Clock"
        let v = w.contentView!
        var y = H - 40
        let title = NSTextField(labelWithString: "Bauhaus Clock options"); title.font = .boldSystemFont(ofSize: 13); title.frame = NSRect(x: 20, y: y, width: 380, height: 20); v.addSubview(title)
        y -= 36
        func popup(_ key: String, _ label: String, _ items: [String]) {
            let l = NSTextField(labelWithString: label); l.alignment = .right; l.frame = NSRect(x: 20, y: y + 3, width: 100, height: 18); v.addSubview(l)
            let p = NSPopUpButton(frame: NSRect(x: 128, y: y - 2, width: 200, height: 26)); p.addItems(withTitles: items); v.addSubview(p); pops[key] = p; y -= 32
        }
        func box(_ key: String, _ label: String) {
            let b = NSButton(checkboxWithTitle: label, target: nil, action: nil); b.frame = NSRect(x: 20, y: y, width: 390, height: 22); v.addSubview(b); boxes[key] = b; y -= 26
        }
        popup("dial", "Dial:", PALETTES.map { $0.name })
        popup("movement", "Movement:", ["Quartz", "Mechanical", "Digital"])
        popup("layout", "Style:", ["Classic", "Compact"])
        popup("size", "Size:", SIZE_OPTIONS.map { $0.0 + " of screen height" })
        y -= 4
        box("seconds", "Seconds hand")
        box("lume", "Lume: show the dial in the dark (glowing markers and hands)")
        box("autoNightLume", "Turn lume on automatically at night (with night dimming)")
        box("nightDim", "Night dimming (10pm–7am, after 3 min)")
        box("bounce", "Bounce slowly around the screen")
        box("explode", "Explode on a perfect corner hit")
        box("cycleDials", "After an explosion, switch to a different dial")
        let ok = NSButton(title: "OK", target: target, action: Selector(("closeSheet:"))); ok.keyEquivalent = "\r"; ok.frame = NSRect(x: 320, y: 16, width: 80, height: 30); ok.bezelStyle = .rounded
        let cancel = NSButton(title: "Cancel", target: target, action: Selector(("cancelSheet:"))); cancel.keyEquivalent = "\u{1b}"; cancel.frame = NSRect(x: 230, y: 16, width: 90, height: 30); cancel.bezelStyle = .rounded
        v.addSubview(ok); v.addSubview(cancel)
        return w
    }
    @objc func closeSheet(_ sender: Any?) {
        for (k, b) in boxes { Prefs.set(k, b.state == .on) }
        for (k, p) in pops { var t = p.titleOfSelectedItem ?? ""; if k == "size" { t = String(t.split(separator: " ").first ?? "2/3") }; Prefs.set(k, t) }
        Prefs.save(); applyPrefs(); endSheet()
    }
    @objc func cancelSheet(_ sender: Any?) { endSheet() }
    private func endSheet() {
        guard let s = sheet else { return }
        if let parent = s.sheetParent { parent.endSheet(s) } else { s.orderOut(nil) }
    }
}
