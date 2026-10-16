import ScreenSaver
import QuartzCore
import AppKit

/// Saved options (System Settings > Screen Saver > Bauhaus Clock > Options…)
/// Stored in a small JSON file in the saver's own (sandbox) home, mirrored to ScreenSaverDefaults.
/// The file is re-read on every load so changes made in the sheet reach the running saver.
enum Prefs {
    static let defaults: ScreenSaverDefaults? = ScreenSaverDefaults(forModuleWithName: "net.clogwog.BauhausClock")
    static let DEFAULTS: [String: Any] = ["lume": false, "autoNightLume": false, "dial": "Noir", "movement": "Digital", "seconds": true,
        "layout": "Classic", "bounce": true, "explode": true, "cycleDials": true, "nightDim": true, "size": "2/3"]
    static var fileURL: URL {
        let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Preferences", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("net.clogwog.BauhausClock.settings.json") }
    static var cache: [String: Any] = [:]
    static func load() {
        var d = DEFAULTS
        if let sd = defaults { for k in DEFAULTS.keys { if let v = sd.object(forKey: k) { d[k] = v } } }
        if let data = try? Data(contentsOf: fileURL), let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { for (k, v) in j { d[k] = v } }
        cache = d }
    static func register() { if cache.isEmpty { load() } }
    static func bool(_ k: String) -> Bool { register(); return (cache[k] as? Bool) ?? (cache[k] as? NSNumber)?.boolValue ?? false }
    static func str(_ k: String) -> String { register(); return cache[k] as? String ?? "" }
    static func set(_ k: String, _ v: Any) { register(); cache[k] = v; defaults?.set(v, forKey: k) }
    static func save() {
        defaults?.synchronize()
        if let data = try? JSONSerialization.data(withJSONObject: cache, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: fileURL, options: .atomic) } }
    static var lume: Bool { bool("lume") }
    static var autoNightLume: Bool { bool("autoNightLume") }
}

/// Visual face picker: mini rendered faces with names; click to select, selection highlighted.
final class FacePicker: NSView {
    var selected = "Noir" { didSet { needsDisplay = true } }
    static let cols = 7, cw: CGFloat = 59, ch: CGFloat = 66
    private var thumbs: [String: NSImage] = [:]
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: CGFloat(Self.cols) * Self.cw, height: CGFloat((PALETTES.count + Self.cols - 1) / Self.cols) * Self.ch) }
    func thumb(_ i: Int) -> NSImage {
        let n = PALETTES[i].name; if let t = thumbs[n] { return t }
        let img = NSImage(size: NSSize(width: 46, height: 46), flipped: false) { r in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            var dc = DateComponents(); dc.year = 2026; dc.month = 10; dc.day = 16; dc.hour = 10; dc.minute = 10; dc.second = 32
            let saved = (LUME_ACTIVE, SHOW_SECONDS); LUME_ACTIVE = false; SHOW_SECONDS = true
            drawClock(ctx, center: CGPoint(x: 23, y: 23), k: 0.225, pal: PALETTES[i], date: Calendar.current.date(from: dc)!)
            (LUME_ACTIVE, SHOW_SECONDS) = saved; return true }
        thumbs[n] = img; return img
    }
    func cell(_ i: Int) -> NSRect { NSRect(x: CGFloat(i % Self.cols) * Self.cw, y: CGFloat(i / Self.cols) * Self.ch, width: Self.cw, height: Self.ch) }
    override func draw(_ dirty: NSRect) {
        let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineBreakMode = .byTruncatingTail
        for i in PALETTES.indices {
            let c = cell(i), name = PALETTES[i].name
            if name == selected {
                let hl = NSBezierPath(roundedRect: c.insetBy(dx: 1.5, dy: 1.5), xRadius: 8, yRadius: 8)
                NSColor.controlAccentColor.withAlphaComponent(0.18).setFill(); hl.fill()
                NSColor.controlAccentColor.setStroke(); hl.lineWidth = 2; hl.stroke() }
            thumb(i).draw(in: NSRect(x: c.minX + 6.5, y: c.minY + 4, width: 46, height: 46), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil);
            (name as NSString).draw(in: NSRect(x: c.minX + 1, y: c.minY + 51, width: c.width - 2, height: 13),
                withAttributes: [.font: NSFont.systemFont(ofSize: 9, weight: name == selected ? .semibold : .regular), .foregroundColor: NSColor.labelColor, .paragraphStyle: para])
        }
    }
    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        if let i = PALETTES.indices.first(where: { cell($0).contains(p) }) { selected = PALETTES[i].name }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
let SIZE_OPTIONS: [(String, CGFloat)] = [("2/3", 3), ("1/2", 4), ("1/3", 6)]

@objc(BauhausClockView)
final class BauhausClockView: ScreenSaverView {
    private var sim: BounceSim?
    private var last: CFTimeInterval = 0
    private var sheet: NSWindow?
    private var boxes: [String: NSButton] = [:]
    private var pops: [String: NSPopUpButton] = [:]
    private var picker: FacePicker?
    override init?(frame: NSRect, isPreview: Bool) { super.init(frame: frame, isPreview: isPreview); setRate() }
    required init?(coder: NSCoder) { super.init(coder: coder); setRate() }
    private func setRate() {
        let fps = (window?.screen ?? NSScreen.main)?.maximumFramesPerSecond ?? 60
        animationTimeInterval = isPreview ? 1.0/30 : 1.0 / Double(max(60, min(fps, 120)))
        wantsLayer = true; layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); setRate() }
    override func startAnimation() { super.startAnimation(); setRate(); last = 0; Prefs.load(); sim = nil }
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
        Prefs.load()
        // Fresh window every time: a cached sheet that the host already closed/ended can't be presented again.
        if let old = sheet, old.isVisible || old.sheetParent != nil { finish(old) }
        boxes = [:]; pops = [:]; picker = nil
        sheet = BauhausClockView.makeSheet(target: self, boxes: &boxes, pops: &pops, picker: &picker)
        picker?.selected = Prefs.str("dial")
        for (k, b) in boxes { b.state = Prefs.bool(k) ? .on : .off }
        for (k, p) in pops { let t = Prefs.str(k); p.selectItem(withTitle: k == "size" ? t + " of screen height" : t) }
        return sheet
    }
    static func makeSheet(target: AnyObject?, boxes: inout [String: NSButton], pops: inout [String: NSPopUpButton], picker: inout FacePicker?) -> NSWindow {
        let H: CGFloat = 640
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: H), styleMask: [.titled], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.title = "Bauhaus Clock"; w.setContentSize(NSSize(width: 430, height: H))
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
        let fl = NSTextField(labelWithString: "Face:"); fl.font = .boldSystemFont(ofSize: 12); fl.frame = NSRect(x: 20, y: y + 6, width: 200, height: 18); v.addSubview(fl)
        let fp = FacePicker(); let fs = fp.intrinsicContentSize; y -= fs.height - 2
        fp.frame = NSRect(x: (430 - fs.width) / 2, y: y, width: fs.width, height: fs.height); v.addSubview(fp); picker = fp; y -= 36
        popup("movement", "Movement:", ["Quartz", "Mechanical", "Digital"])
        popup("layout", "Style:", ["Classic", "Compact"])
        popup("size", "Size:", SIZE_OPTIONS.map { $0.0 + " of screen height" })
        y -= 4
        box("seconds", "Seconds hand")
        box("lume", "Lume: show the dial in the dark (glowing markers and hands)")
        box("autoNightLume", "Auto lume at night only when ticked (10pm–7am, after 3 min)")
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
        if let fp = picker { Prefs.set("dial", fp.selected) }
        Prefs.save(); Prefs.load(); applyPrefs(); endSheet()
    }
    @objc func cancelSheet(_ sender: Any?) { endSheet() }
    private func endSheet() {
        guard let s = sheet else { return }
        finish(s)
        sheet = nil; boxes = [:]; pops = [:]; picker = nil   // drop controls so the old sheet can't linger
    }
    private func finish(_ s: NSWindow) {
        if let parent = s.sheetParent { parent.endSheet(s, returnCode: .OK) }
        else if s.isSheet { NSApp.endSheet(s) }
        s.orderOut(nil)
    }
    var hasOpenSheet: Bool { sheet != nil }
}
