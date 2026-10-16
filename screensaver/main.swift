import AppKit
func render(_ sim: BounceSim, _ name: String, _ date: Date) {
    let W = Int(sim.size.width), H = Int(sim.size.height)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    sim.draw(g.cgContext, date: date); g.flushGraphics()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
}
var fails = 0
func check(_ c: Bool, _ m: String) { print((c ? "PASS " : "FAIL ") + m); if !c { fails += 1 } }
func at(_ h: Int, _ mi: Int = 9) -> Date { var d = DateComponents(); d.year = 2026; d.month = 10; d.day = 16; d.hour = h; d.minute = mi; d.second = 36; return Calendar.current.date(from: d)! }
let S = CGSize(width: 1920, height: 1080), day = at(10)
let a = BounceSim(size: S); a.pos = CGPoint(x: 700, y: 400); a.vel = CGVector(dx: 60, dy: 45)
for _ in 0..<120 { a.step(1.0/60, date: day) }
check(abs(a.pos.x - 820) < 0.5 && abs(a.pos.y - 490) < 0.5, "constant velocity, 2 s at 60fps -> \(a.pos)")
check(a.radius == 360, "diameter = 2/3 H = \(a.radius*2)")
check(abs(a.speed - 30) < 0.001 && abs(BounceSim(size: CGSize(width: 3840, height: 2160)).speed - 60) < 0.001, "speed 30 px/s @1080p, scales to 60 @2160p")
let b = BounceSim(size: S); b.pos = CGPoint(x: 700, y: 400); b.vel = CGVector(dx: 60, dy: 45)
for _ in 0..<20 { b.step(0.1, date: day) }
check(abs(b.pos.x - 820) < 0.5 && abs(b.pos.y - 490) < 0.5, "frame-rate independent (10fps same pos \(b.pos))")
render(a, "bounce.png", day)
let lt = BounceSim(size: S); lt.pos = CGPoint(x: 1100, y: 560); lt.pal = PALETTES.firstIndex { $0.name == "Cream" }!; render(lt, "bounce-light.png", day)
let e = BounceSim(size: S); e.pos = CGPoint(x: 1920-360-40, y: 540); e.vel = CGVector(dx: 30, dy: 16)
for _ in 0..<240 { e.step(1.0/60, date: day) }
check(e.vel.dx < 0 && e.corners == 0 && e.pos.x <= 1920 - 360, "side wall reflects, no explosion")
let c = BounceSim(size: S); c.pos = CGPoint(x: 1920-360-30, y: 1080-360-30); c.vel = CGVector(dx: 30, dy: 30)
let p0 = c.pal
for _ in 0..<70 { c.step(1.0/60, date: day) }
check(c.corners == 1, "exact top-right corner triggers explosion")
if case .exploding = c.phase { check(true, "phase = exploding") } else { check(false, "phase = exploding") }
check(c.particles.filter { if case .hourBar = $0.prim { return true }; return false }.count == 12 && c.particles.filter { if case .hand = $0.prim { return true }; return false }.count == 2, "explosion includes 12 hour bars + 2 hands")
check(c.particles.count == 76, "76 fragments (12 shards, 12 bars, 48 ticks, 3 hands, cap; no numerals)")
for _ in 0..<40 { c.step(1.0/60, date: day) }
render(c, "explode.png", day)
for _ in 0..<90 { c.step(1.0/60, date: day) }
var resp = false; if case .exploding = c.phase {} else { resp = true }
check(resp, "new clock after ~1.8 s")
check(c.pal != p0, "new colour differs (\(PALETTES[p0].name) -> \(PALETTES[c.pal].name))")
let n = BounceSim(size: S); n.pos = CGPoint(x: 1920-360-30, y: 1080-360-30-2); n.vel = CGVector(dx: 30, dy: 30)
for _ in 0..<70 { n.step(1.0/60, date: day) }
check(n.corners == 1, "2px off still counts (tol \(n.cornerTol)px)")
let m = BounceSim(size: S); m.pos = CGPoint(x: 1920-360-30, y: 1080-360-30-20); m.vel = CGVector(dx: 30, dy: 30)
for _ in 0..<70 { m.step(1.0/60, date: day) }
check(m.corners == 0, "20px miss does not explode")
let l = BounceSim(size: S); l.pos = CGPoint(x: 390, y: 390); l.vel = CGVector(dx: -30, dy: -30)
for _ in 0..<40 { l.step(1.0/30, date: day) }
check(l.corners == 1, "bottom-left corner at 30fps")
let r = BounceSim(size: S); var ok = true
for _ in 0..<500 { let o = r.pal; r.respawn(newPalette: true); ok = ok && r.pal != o }
check(ok, "500 respawns never repeat colour")
// sub-pixel smoothness: per-frame step at 60fps is 0.5px and never rounded
let sp = BounceSim(size: S); sp.pos = CGPoint(x: 900, y: 500); sp.vel = CGVector(dx: 30, dy: 0); sp.step(1.0/60, date: day)
check(abs(sp.pos.x - 900.5) < 1e-6, "sub-pixel positions kept (x=\(sp.pos.x))")
let sk = BounceSim(size: S); sk.pos = CGPoint(x: 900, y: 500); sk.vel = CGVector(dx: 30, dy: 0); sk.step(5.0, date: day)
check(abs(sk.pos.x - 903) < 1e-6, "5 s dt spike clamped to 0.1 s (x=\(sk.pos.x))")
// Night dimming
let dn = BounceSim(size: S), night = at(23)
for _ in 0..<(179*10) { dn.step(0.1, date: night) }
check(dn.brightness == 1, "no dimming before 3 min (\(dn.brightness))")
for _ in 0..<(5*10) { dn.step(0.1, date: night) }
check(dn.brightness > 0.6 && dn.brightness < 0.75, "mid-fade ~4 s in (\(dn.brightness))")
for _ in 0..<(8*10) { dn.step(0.1, date: night) }
check(abs(dn.brightness - 0.33) < 0.001, "dimmed to 33% (\(dn.brightness))")
render(dn, "dim.png", night)
for _ in 0..<(11*10) { dn.step(0.1, date: at(7, 0)) }
check(dn.brightness == 1, "fades back up at 07:00 (\(dn.brightness))")
let dd = BounceSim(size: S); for _ in 0..<(200*10) { dd.step(0.1, date: day) }
check(dd.brightness == 1, "no dimming in daytime")
// Thumbnails for System Settings: clock at 1/3 height with ghosted trail
func thumb(_ W: Int, _ H: Int, _ name: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!, ctx = g.cgContext
    let sim = BounceSim(size: CGSize(width: W, height: H)); let r = sim.radius, k = sim.k
    ctx.setFillColor(CGColor(gray: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    // longer, more prominent trail: 7 ghosts along a long diagonal, opacity fading toward the tail
    let m = CGFloat(H) * 0.035, end = CGPoint(x: CGFloat(W) - r - m, y: CGFloat(H) - r - m), dir = CGVector(dx: -0.8, dy: -0.6)   // fully inside, top-right; trail down-left
    let ghosts = 7
    for i in stride(from: ghosts, through: 1, by: -1) {
        let al = 0.42 * pow(1 - Double(i - 1) / Double(ghosts), 1.6) + 0.04
        let p = CGPoint(x: end.x + dir.dx * r * 0.2 * CGFloat(i), y: end.y + dir.dy * r * 0.2 * CGFloat(i))
        drawClock(ctx, center: p, k: k, pal: PALETTES[NOIR], date: day, alpha: CGFloat(al))
    }
    drawClock(ctx, center: end, k: k, pal: PALETTES[NOIR], date: day)
    g.flushGraphics()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
}
thumb(280, 175, "thumbnail.png"); thumb(560, 350, "thumbnail@2x.png")
// preview-size sim scales correctly
let pv = BounceSim(size: CGSize(width: 280, height: 175))
check(abs(pv.radius*2 - 175.0*2/3) < 0.01 && abs(pv.speed - 175*30/1080.0) < 0.001, "preview view scales (d=\(pv.radius*2), v=\(pv.speed))")
// reference-matched crop: R = 470 px, centre (488,470) in a 961x589 frame, 10:09:13.7
do {
    let W = 961, H = 589
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!, cx = g.cgContext
    cx.setFillColor(PALETTES[NOIR].dial); cx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    var dc = DateComponents(); dc.year = 2026; dc.month = 10; dc.day = 16; dc.hour = 10; dc.minute = 9; dc.second = 13; dc.nanosecond = 700_000_000
    drawClock(cx, center: CGPoint(x: 488, y: CGFloat(H) - 470), k: 4.7, pal: PALETTES[NOIR], date: Calendar.current.date(from: dc)!)
    g.flushGraphics(); try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "refcrop.png"))
}
check(!c.particles.contains { if case .numeral = $0.prim { return true }; return false }, "no numeral pieces in explosion")
// crisp-shadow crops: overlap at 10:52:10 and minute hand over the 2 o'clock bar at 10:09:48
for (name, hh, mm, ss) in [("crisp-overlap.png", 10, 52, 10), ("crisp-bar.png", 10, 9, 48)] {
    let W = 1100, H = 1100
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!, cx = g.cgContext
    cx.setFillColor(PALETTES[NOIR].dial); cx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    var dc = DateComponents(); dc.year = 2026; dc.month = 10; dc.day = 16; dc.hour = hh; dc.minute = mm; dc.second = ss; dc.nanosecond = 300_000_000
    drawClock(cx, center: CGPoint(x: 550, y: 550), k: 4.7, pal: PALETTES[NOIR], date: Calendar.current.date(from: dc)!)
    g.flushGraphics(); try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
}
// Pixel check: shadows may only darken. Render 10:09:48 with and without hand shadows; compare.
func px(_ on: Bool, _ palIdx: Int) -> NSBitmapImageRep {
    SHADOWS_ON = on
    let W = 1100, H = 1100
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!, cx = g.cgContext
    cx.setFillColor(PALETTES[palIdx].dial); cx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    var dc = DateComponents(); dc.year = 2026; dc.month = 10; dc.day = 16; dc.hour = 10; dc.minute = 52; dc.second = 10
    drawClock(cx, center: CGPoint(x: 550, y: 550), k: 4.7, pal: PALETTES[palIdx], date: Calendar.current.date(from: dc)!)
    g.flushGraphics(); SHADOWS_ON = true; return rep
}
for pi in [NOIR, PALETTES.firstIndex { $0.name == "Cream" }!] {
    let a = px(true, pi), b = px(false, pi); var darker = 0, lighter = 0, maxUp = 0
    let pa = a.bitmapData!, pb = b.bitmapData!, n = a.bytesPerRow * a.pixelsHigh
    var i = 0
    while i < n { let la = Int(pa[i]) + Int(pa[i+1]) + Int(pa[i+2]), lb = Int(pb[i]) + Int(pb[i+1]) + Int(pb[i+2])
        if la < lb - 2 { darker += 1 } else if la > lb + 2 { lighter += 1; maxUp = max(maxUp, la - lb) }; i += 4 }
    check(darker > 1000 && lighter == 0, "\(PALETTES[pi].name): shadows only darken (darker px \(darker), lighter px \(lighter), max lift \(maxUp))")
}
// big clock still has room to bounce on common aspect ratios, and respawns fully on screen
for sz in [CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1600), CGSize(width: 1440, height: 900), CGSize(width: 280, height: 175)] {
    let b = BounceSim(size: sz); var inside = true
    for _ in 0..<200 { b.respawn(newPalette: true); inside = inside && b.pos.x - b.radius >= 0 && b.pos.x + b.radius <= sz.width && b.pos.y - b.radius >= 0 && b.pos.y + b.radius <= sz.height }
    check(sz.width - 2*b.radius > 0 && sz.height - 2*b.radius > 0 && inside, "\(Int(sz.width))x\(Int(sz.height)): room x=\(Int(sz.width - 2*b.radius)) y=\(Int(sz.height - 2*b.radius)), respawns inside")
}
// long run: never leaves the screen
let lr = BounceSim(size: S); var maxOut: CGFloat = 0
for _ in 0..<(600*60) { lr.step(1.0/60, date: day); if case .moving = lr.phase { maxOut = max(maxOut, lr.radius - lr.pos.x, lr.pos.x + lr.radius - 1920, lr.radius - lr.pos.y, lr.pos.y + lr.radius - 1080) } }
check(maxOut <= 0.001, "10 min run stays on screen (max overshoot \(maxOut))")
check({ let r = CGFloat(175)/3, m = CGFloat(175)*0.035; return 280 - r - m + r <= 280 && 175 - r - m + r <= 175 && 175 - r - m - 7*0.2*r*0.6 - r >= 0 }(), "thumbnail clock and trail fit inside the frame")
// Lume: option and automatic night lume
func cyanCount(_ lume: Bool) -> Int {
    LUME_ACTIVE = lume; defer { LUME_ACTIVE = false }
    let W = 800, H = 800
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!, cx = g.cgContext
    cx.setFillColor(CGColor(gray: 0, alpha: 1)); cx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    drawClock(cx, center: CGPoint(x: 400, y: 400), k: 3.8, pal: PALETTES[NOIR], date: day)
    g.flushGraphics(); if lume { try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "lume.png")) }
    let p = rep.bitmapData!; var n = 0, i = 0
    while i < rep.bytesPerRow * H { if p[i] < 120 && p[i+1] > 170 && p[i+2] > 170 { n += 1 }; i += 4 }
    return n
}
let cyanOff = cyanCount(false), cyanOn = cyanCount(true)
check(cyanOff == 0 && cyanOn > 3000, "lume draws glowing cyan (off \(cyanOff) px, on \(cyanOn) px)")
let ln = BounceSim(size: S); ln.autoNightLume = true
for _ in 0..<(179*10) { ln.step(0.1, date: at(23)) }
check(!ln.lumeActive, "no auto lume before 3 min at night")
for _ in 0..<(5*10) { ln.step(0.1, date: at(23)) }
check(ln.lumeActive, "auto lume on with night dimming")
for _ in 0..<(12*10) { ln.step(0.1, date: at(8, 0)) }
check(!ln.lumeActive, "auto lume off again by day")
ln.autoNightLume = false; for _ in 0..<(5*10) { ln.step(0.1, date: at(23)) }
check(!ln.lumeActive, "auto lume can be disabled")
ln.prefLume = true; check(ln.lumeActive, "Lume option forces lume on any time")

// ---- v1.15: all dials, special faces, movements, cache ----
check(PALETTES.count == 19 && PALETTES[NOIR].name == "Noir", "19 dials (16 colours + Pilot, Diver, Chronograph)")
do {   // movements: second-hand angle at hh:mm:36.30
    var dc = DateComponents(); dc.year = 2026; dc.month = 10; dc.day = 16; dc.hour = 10; dc.minute = 9; dc.second = 36; dc.nanosecond = 300_000_000
    let d = Calendar.current.date(from: dc)!
    MOVEMENT = "Digital"; let dg = handAngles(d).s; MOVEMENT = "Mechanical"; let me = handAngles(d).s; MOVEMENT = "Quartz"; let qz = handAngles(d).s; MOVEMENT = "Digital"
    check(abs(dg - 36.3*6) < 0.01 && abs(me - 36.25*6) < 0.01 && abs(qz - 36*6) < 0.01, "movements: digital \(dg), mechanical \(me), quartz \(qz)")
}
// contact sheet: every dial, plus lume views
func tile(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ pal: Int, _ lume: Bool, _ label: String) {
    LUME_ACTIVE = lume; defer { LUME_ACTIVE = false }
    ctx.setFillColor(hex("#202022")); ctx.fill(CGRect(x: x, y: y, width: 420, height: 470))
    var dc = DateComponents(); dc.year = 2026; dc.month = 10; dc.day = 16; dc.hour = 10; dc.minute = 10; dc.second = 32
    drawClock(ctx, center: CGPoint(x: x + 210, y: y + 260), k: 1.95, pal: PALETTES[pal], date: Calendar.current.date(from: dc)!)
    ctx.saveGState(); ctx.translateBy(x: x + 210, y: y + 30); ctx.scaleBy(x: 1, y: -1); Pen(ctx).text(label, 0, 0, size: 22, color: hex("#dddddd")); ctx.restoreGState()
}
do {
    var items: [(Int, Bool, String)] = PALETTES.indices.map { ($0, false, PALETTES[$0].name) }
    items += [(NOIR, true, "Lume"), (paletteIndex("Pilot"), true, "Pilot · lume"), (paletteIndex("Diver"), true, "Diver · lume"), (paletteIndex("Chronograph"), true, "Chronograph · lume")]
    let cols = 6, rows = (items.count + cols - 1) / cols, W = cols * 420, H = rows * 470
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!, cx = g.cgContext
    cx.setFillColor(hex("#111111")); cx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for (i, it) in items.enumerated() { tile(cx, CGFloat(i % cols * 420), CGFloat(H - (i / cols + 1) * 470), it.0, it.1, it.2) }
    g.flushGraphics(); try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "dials-sheet.png"))
    // big single renders of the special faces for side-by-side comparison with the web
    for (n, lume) in [("Pilot", false), ("Diver", false), ("Chronograph", false), ("Pilot", true), ("Diver", true), ("Chronograph", true)] {
        let r2 = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1000, pixelsHigh: 1000, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let g2 = NSGraphicsContext(bitmapImageRep: r2)!, c2 = g2.cgContext
        c2.setFillColor(PALETTES[paletteIndex(n)].dial); c2.fill(CGRect(x: 0, y: 0, width: 1000, height: 1000))
        LUME_ACTIVE = lume
        var dc = DateComponents(); dc.year = 2026; dc.month = 10; dc.day = 16; dc.hour = 10; dc.minute = 10; dc.second = 32
        drawClock(c2, center: CGPoint(x: 500, y: 500), k: 3.47, pal: PALETTES[paletteIndex(n)], date: Calendar.current.date(from: dc)!)
        LUME_ACTIVE = false
        g2.flushGraphics(); try! r2.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "saver-\(n.lowercased())\(lume ? "-lume" : "").png"))
    }
}
do {   // perf: Pilot frames reuse the cached static layer
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1920, pixelsHigh: 1080, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!, cx = g.cgContext
    let sim = BounceSim(size: S); sim.pal = paletteIndex("Pilot")
    let before = faceCacheCount(); let t0 = Date()
    for i in 0..<120 { sim.step(1.0/60, date: day); sim.draw(cx, date: day.addingTimeInterval(Double(i)/60)) }
    let ms = Date().timeIntervalSince(t0) * 1000 / 120
    check(faceCacheCount() - before <= 1, "Pilot static layer built once for 120 frames (cache +\(faceCacheCount() - before))")
    check(ms < 16, String(format: "Pilot frame time %.2f ms at 1080p", ms))
}
let kd = BounceSim(size: S); kd.cycleDials = false; kd.pal = paletteIndex("Diver"); kd.respawn(newPalette: true)
check(kd.pal == paletteIndex("Diver"), "keep-dial option keeps the chosen dial after an explosion")
print(fails == 0 ? "ALL PASS" : "\(fails) FAILED")
exit(fails == 0 ? 0 : 1)
