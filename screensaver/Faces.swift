import AppKit
import CoreText

// ---- Special watch faces (ported from index.html: speedFace/chronoDark, diverFace, pilotFace) ----
// Same svg-style space as the Bauhaus face: R = 100, y down. Static parts are rendered once per
// (face, lume, pixel size, day) into a bitmap; only hands, cap and running subdial are drawn per frame.

enum Face: String { case chrono = "Chronograph", diver = "Diver", pilot = "Pilot" }
func faceFor(_ p: Palette) -> Face? { Face(rawValue: p.name) }

var MOVEMENT = "Digital"      // Quartz | Mechanical | Digital
var SHOW_SECONDS = true
var COMPACT = false           // Compact layout: no minute ticks on colour dials

private let RGB = CGColorSpace(name: CGColorSpace.sRGB)!
func hexA(_ s: String, _ a: CGFloat) -> CGColor { hex(s).copy(alpha: a)! }
let PC_GRAD = CGGradient(colorsSpace: RGB, colors: [hex("#f0f0f0"), hex("#9c9c9c")] as CFArray, locations: [0, 1])!

final class Pen {
    let c: CGContext
    init(_ c: CGContext) { self.c = c }
    var k: CGFloat { let t = c.ctm; return hypot(t.a, t.b) }
    func P(_ r: CGFloat, _ a: CGFloat) -> CGPoint { let t = a * .pi / 180; return CGPoint(x: sin(t) * r, y: -cos(t) * r) }
    func disc(_ r: CGFloat, _ cx: CGFloat = 0, _ cy: CGFloat = 0) -> CGRect { CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r) }
    func circle(_ r: CGFloat, fill: CGColor? = nil, stroke: CGColor? = nil, sw: CGFloat = 0, cx: CGFloat = 0, cy: CGFloat = 0) {
        if let f = fill { c.setFillColor(f); c.fillEllipse(in: disc(r, cx, cy)) }
        if let s = stroke { c.setStrokeColor(s); c.setLineWidth(sw); c.strokeEllipse(in: disc(r, cx, cy)) }
    }
    /// SVG-style radialGradient on a circle of radius r (cx/cy/rr as fractions of the bounding box).
    func radial(_ r: CGFloat, _ stops: [(CGFloat, String)], cx: CGFloat = 0.5, cy: CGFloat = 0.5, rr: CGFloat = 0.5, ox: CGFloat = 0, oy: CGFloat = 0) {
        let g = CGGradient(colorsSpace: RGB, colors: stops.map { hex($0.1) } as CFArray, locations: stops.map { $0.0 })!
        let ctr = CGPoint(x: ox + (cx - 0.5) * 2 * r, y: oy + (cy - 0.5) * 2 * r)
        c.saveGState(); c.addEllipse(in: disc(r, ox, oy)); c.clip()
        c.drawRadialGradient(g, startCenter: ctr, startRadius: 0, endCenter: ctr, endRadius: rr * 2 * r, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        c.restoreGState()
    }
    func capDisc(_ r: CGFloat) {   // url(#pc): cx 42% cy 38% r 70%
        let ctr = CGPoint(x: -0.16 * r, y: -0.24 * r)
        c.saveGState(); c.addEllipse(in: disc(r)); c.clip()
        c.drawRadialGradient(PC_GRAD, startCenter: ctr, startRadius: 0, endCenter: ctr, endRadius: 1.4 * r, options: [.drawsAfterEndLocation]); c.restoreGState()
    }
    func tick(_ r1: CGFloat, _ r2: CGFloat, _ a: CGFloat, _ w: CGFloat, _ col: CGColor) {
        c.setStrokeColor(col); c.setLineWidth(w); c.move(to: P(r1, a)); c.addLine(to: P(r2, a)); c.strokePath()
    }
    func poly(_ pts: [(CGFloat, CGFloat)]) -> CGPath { let p = CGMutablePath(); p.addLines(between: pts.map { CGPoint(x: $0.0, y: $0.1) }); p.closeSubpath(); return p }
    func fill(_ p: CGPath, _ col: CGColor) { c.addPath(p); c.setFillColor(col); c.fillPath() }
    func stroke(_ p: CGPath, _ col: CGColor, _ w: CGFloat) { c.addPath(p); c.setStrokeColor(col); c.setLineWidth(w); c.strokePath() }
    func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rx: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: min(rx, w / 2), cornerHeight: min(rx, h / 2), transform: nil) }
    func ell(_ r: CGFloat, _ cx: CGFloat = 0, _ cy: CGFloat = 0) -> CGPath { CGPath(ellipseIn: disc(r, cx, cy), transform: nil) }
    func rot(_ a: CGFloat, _ f: () -> Void) { c.saveGState(); c.rotate(by: a * .pi / 180); f(); c.restoreGState() }
    func at(_ x: CGFloat, _ y: CGFloat, _ f: () -> Void) { c.saveGState(); c.translateBy(x: x, y: y); f(); c.restoreGState() }
    /// Soft lume bloom (≈ feGaussianBlur 1.6 + 0.5 merged) plus a crisp core.
    func glow(_ p: CGPath, _ col: CGColor) {
        for (blur, a) in [(3.4, 0.95), (1.0, 1.0)] as [(CGFloat, CGFloat)] {
            c.saveGState(); c.setShadow(offset: .zero, blur: blur * k, color: col.copy(alpha: a)!); fill(p, col); c.restoreGState() }
        fill(p, col)
    }
    /// Shadow silhouette: multiply-blended, offset down-left in unrotated space (darken only).
    func shadow(_ deg: CGFloat, _ path: CGPath, _ col: CGColor, tx: CGFloat = 0, ty: CGFloat = 0) {
        guard SHADOWS_ON else { return }
        c.saveGState(); c.setBlendMode(.multiply); c.translateBy(x: tx + SHADOW_DX, y: ty + SHADOW_DY); c.rotate(by: deg * .pi / 180)
        fill(path, col); c.restoreGState()
    }
    private var fonts: [String: CTFont] = [:]
    func font(_ name: String, _ size: CGFloat) -> CTFont {
        let key = "\(name)@\(size)"; if let f = fonts[key] { return f }
        let f = CTFontCreateWithName(name as CFString, size, nil); fonts[key] = f; return f
    }
    func line(_ s: String, _ f: CTFont, _ col: CGColor, _ kern: CGFloat) -> (CTLine, CGFloat) {
        var attrs: [NSAttributedString.Key: Any] = [.init(kCTFontAttributeName as String): f, .init(kCTForegroundColorAttributeName as String): col]
        if kern != 0 { attrs[.init(kCTKernAttributeName as String)] = kern }
        let l = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
        return (l, CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil)) - (kern != 0 ? kern : 0))
    }
    /// SVG text: translate(x y) rotate(rot) translate(0 dy), text-anchor middle, baseline at 0.
    func text(_ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, color: CGColor, font name: String = "HelveticaNeue",
              rot: CGFloat = 0, dy: CGFloat = 0, kern: CGFloat = 0, glow g: CGColor? = nil) {
        let (l, w) = line(s, font(name, size), color, kern)
        c.saveGState(); c.translateBy(x: x, y: y); c.rotate(by: rot * .pi / 180); c.translateBy(x: 0, y: dy)
        c.scaleBy(x: 1, y: -1); c.textMatrix = .identity; c.textPosition = CGPoint(x: -w / 2, y: 0)
        if let g = g { c.setShadow(offset: .zero, blur: 3.4 * k, color: g) }
        CTLineDraw(l, c); c.restoreGState()
    }
    /// Text set along a circle (letters upright toward the centre), centred on angle `mid`.
    func arcText(_ s: String, r: CGFloat, mid: CGFloat, size: CGFloat, color: CGColor, kern: CGFloat) {
        let f = font("HelveticaNeue", size)
        let ws = s.map { line(String($0), f, color, 0).1 + kern }
        let total = ws.reduce(0, +) - kern
        var a = mid - total / r * 180 / .pi / 2
        for (ch, w) in zip(s, ws) {
            let am = a + (w - kern) / 2 / r * 180 / .pi, p = P(r, am)
            text(String(ch), p.x, p.y, size: size, color: color, rot: am, dy: size * 0.35)
            a += w / r * 180 / .pi
        }
    }
}

// ---- static layer cache ----
private var FACE_CACHE: [String: CGImage] = [:]
func faceImage(_ f: Face, dark: Bool, pxPerUnit: CGFloat, date: Date) -> CGImage {
    let n = max(8, Int(ceil(200 * pxPerUnit)))
    let day = f == .diver && !dark ? Calendar.current.component(.day, from: date) : 0
    let key = "\(f.rawValue)|\(dark)|\(n)|\(day)"
    if let img = FACE_CACHE[key] { return img }
    let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: RGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true); ctx.interpolationQuality = .high
    ctx.translateBy(x: CGFloat(n) / 2, y: CGFloat(n) / 2); let s = CGFloat(n) / 200; ctx.scaleBy(x: s, y: -s)
    let p = Pen(ctx)
    switch (f, dark) {
    case (.chrono, false): chronoStatic(p)
    case (.chrono, true): chronoDarkStatic(p)
    case (.diver, _): diverStatic(p, dark: dark, day: day)
    case (.pilot, _): pilotStatic(p, dark: dark)
    }
    let img = ctx.makeImage()!
    if FACE_CACHE.count > 16 { FACE_CACHE.removeAll() }
    FACE_CACHE[key] = img; return img
}
func faceCacheCount() -> Int { FACE_CACHE.count }

/// Draw a special face at view point c (k = view points per svg unit; drawK = current zoom for appear animations).
func drawSpecial(_ ctx: CGContext, center c: CGPoint, k: CGFloat, drawK: CGFloat, face: Face, date: Date) {
    let dev = hypot(ctx.ctm.a, ctx.ctm.b)
    let img = faceImage(face, dark: LUME_ACTIVE, pxPerUnit: k * dev, date: date)
    let R = DIAL_R * drawK
    ctx.saveGState(); ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R)); ctx.restoreGState()
    ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.scaleBy(x: drawK, y: -drawK)
    specialHands(Pen(ctx), face, dark: LUME_ACTIVE, date: date)
    ctx.restoreGState()
}

// ===== Chronograph =====
private let CW = hex("#f2f2f2"), CLM = hex("#d9e4c4"), CDG = hex("#cfe8b0")
private let TACHY = [500,400,350,300,275,250,225,200,180,160,150,140,130,120,110,100,90,85,80,75,70,65,60]
private func chronoBatons(_ p: Pen, _ col: CGColor, glow: Bool) {
    func put(_ path: CGPath) { if glow { p.glow(path, col) } else { p.fill(path, col); p.stroke(path, hex("#8f9a7e"), 0.2) } }
    for i in 0..<12 {
        if i == 0 { put(p.rrect(-1.15, -76, 2.3, 13, 0.6)); if glow { p.glow(p.ell(1.25, -3.6, -64.8), col); p.glow(p.ell(1.25, 3.6, -64.8), col) } else { p.fill(p.ell(1.25, -3.6, -64.8), col); p.fill(p.ell(1.25, 3.6, -64.8), col) }; continue }
        p.rot(CGFloat(i * 30)) { put(p.rrect(-1.15, -76, 2.3, i % 3 == 0 ? 8 : 12, 0.6)) }
    }
}
func chronoStatic(_ p: Pen) {
    p.circle(99.5, fill: hex("#bdbdbd"))
    p.radial(98.6, [(0.86, "#232425"), (0.93, "#121313"), (1, "#2b2c2d")])
    p.circle(85.6, fill: hex("#0c0c0d"))
    p.radial(85, [(0, "#2a2b2d"), (1, "#151617")], cy: 0.45, rr: 0.6)
    for v in TACHY { let a = 3600 / CGFloat(v) * 6, q = p.P(91.2, a)
        p.text("\(v)", q.x, q.y, size: 4.7, color: CW, rot: a > 100 && a < 260 ? a + 180 : a, dy: 1.7) }
    var v: CGFloat = 500
    while v >= 60 { let a = 3600 / v * 6
        if a <= 358 { let big = v == v.rounded() && TACHY.contains(Int(v)); p.tick(85.8, big ? 88.2 : 87.2, a, 0.35, CW) }
        v -= v > 200 ? 25 : v > 100 ? 5 : v > 80 ? 2.5 : 1 }
    p.arcText("TACHYMÈTRE", r: 91.9, mid: 21, size: 4.4, color: CW, kern: 0.8)
    for i in 0..<300 { let m = i % 5 == 0; p.tick(84, m ? 78.6 : 81.6, CGFloat(i) * 1.2, m ? 0.55 : 0.25, m ? CW : CW.copy(alpha: 0.8)!) }
    chronoBatons(p, CLM, glow: false)
    p.text("CHRONOGRAPH", 0, -40, size: 4.2, color: CW.copy(alpha: 0.9)!, kern: 1.4)
    func sub(_ cx: CGFloat, _ cy: CGFloat, _ nums: [String], _ run: Bool) {
        p.at(cx, cy) {
            p.circle(18.5, fill: hex("#111213")); p.circle(18, fill: hex("#191a1b"), stroke: hex("#0a0a0a"), sw: 0.5)
            var r: CGFloat = 2; while r < 18 { p.circle(r, stroke: CGColor(gray: 1, alpha: r.truncatingRemainder(dividingBy: 1.6) < 0.8 ? 0.035 : 0.015), sw: 0.18); r += 0.8 }
            let n = run ? 60 : nums.count * 5
            for i in 0..<n { let a = CGFloat(i) * 360 / CGFloat(n), M = i % (n / nums.count) == 0; p.tick(17.4, M ? 14.6 : 15.9, a, M ? 0.5 : 0.28, CW) }
            for (i, t) in nums.enumerated() where !t.isEmpty { let q = p.P(10.4, CGFloat(i) * 360 / CGFloat(nums.count))
                p.text(t, q.x, q.y + 2, size: 5.4, color: CW, font: "HelveticaNeue-Medium") }
        }
    }
    sub(-38, 0, ["60", "", "20", "", "40", ""], true); sub(38, 0, ["30", "", "10", "", "20", ""], false); sub(0, 38, ["12", "3", "6", "9"], false)
    for (x, y, a) in [(38, 0, 24), (0, 38, 312)] as [(CGFloat, CGFloat, CGFloat)] {
        p.shadow(a, chronoSubHand(p), CGColor(gray: 0, alpha: 0.6), tx: x, ty: y)
        p.at(x, y) { p.rot(a) { p.fill(chronoSubHand(p), CW); p.fill(p.ell(1.6), CW) }; p.fill(p.ell(0.7), hex("#777777")) }
    }
}
private func chronoSubHand(_ p: Pen) -> CGPath { p.poly([(-0.6, 3), (-0.36, -15), (0.36, -15), (0.6, 3)]) }
func chronoDarkStatic(_ p: Pen) {
    p.circle(99.5, fill: hex("#060707")); p.circle(85, fill: hex("#030404"))
    chronoBatons(p, CDG, glow: true)
}

// ===== Diver =====
private let DW = hex("#f4f4f4")
func diverStatic(_ p: Pen, dark: Bool, day: Int) {
    let LM = dark ? hex("#cfe8b0") : hex("#dfe9c8"), c = p.c
    if dark { p.circle(99.5, fill: hex("#05070b")); p.circle(80, fill: hex("#02040a")) }
    else {
        p.radial(99.5, [(0.9, "#8e8e8e"), (0.95, "#e8e8e8"), (1, "#9a9a9a")])
        c.saveGState(); c.addEllipse(in: p.disc(97)); c.clip()
        c.drawLinearGradient(CGGradient(colorsSpace: RGB, colors: [hex("#2c4aa0"), hex("#1a2f72")] as CFArray, locations: [0, 1])!, start: CGPoint(x: 0, y: -97), end: CGPoint(x: 0, y: 97), options: []); c.restoreGState()
        p.circle(97, stroke: hex("#0d1838"), sw: 0.6)
        p.circle(80.4, fill: hex("#0a0f1c")); p.radial(80, [(0, "#1f2c4a"), (1, "#0e1526")], cy: 0.45, rr: 0.6)
        // horizontal wave pattern (8 x 4.2 tile)
        c.saveGState(); c.addEllipse(in: p.disc(80)); c.clip()
        for (off, col, w) in [(CGFloat(0), CGColor(gray: 0, alpha: 0.28), CGFloat(0.9)), (0.8, hexA("#5f7bb8", 0.18), 0.35)] {
            let path = CGMutablePath(); var y: CGFloat = -84
            while y < 84 { var x: CGFloat = -88; let yy = y + 2.1 + off; path.move(to: CGPoint(x: x, y: yy))
                while x < 88 { path.addQuadCurve(to: CGPoint(x: x + 4, y: yy), control: CGPoint(x: x + 2, y: yy - 1.5))
                    path.addQuadCurve(to: CGPoint(x: x + 8, y: yy), control: CGPoint(x: x + 6, y: yy + 1.5)); x += 8 }
                y += 4.2 }
            p.stroke(path, col, w) }
        c.restoreGState()
        for m in 1..<60 { let a = CGFloat(m * 6)
            if m % 5 == 0 { if m % 10 != 0 { p.rot(a) { p.fill(p.rrect(-1.1, -95, 2.2, 9, 0.4), DW) } } }
            else if m < 15 { let q = p.P(89, a); p.fill(p.ell(0.9, q.x, q.y), DW) } }
        for v in [10, 20, 30, 40, 50] { let a = CGFloat(v * 6), q = p.P(88.6, a)
            p.text("\(v)", q.x, q.y, size: 10.5, color: DW, font: "HelveticaNeue-Bold", rot: v == 30 ? 0 : a, dy: 3.6) }
        let tri = p.poly([(-5.6, -96), (5.6, -96), (0, -85.6)]); p.fill(tri, DW); p.stroke(tri, hex("#cccccc"), 0.3)
        for i in 0..<60 where i % 5 != 0 { p.tick(79, 75.5, CGFloat(i * 6), 0.45, DW) }
        p.text("PROFESSIONAL", 0, 33, size: 4, color: DW, kern: 0.5)
        p.text("300m / 1000ft", 0, 39.5, size: 5, color: DW)
        let win = CGPath(rect: CGRect(x: 46, y: -5.2, width: 13, height: 10.4), transform: nil)
        p.fill(win, hex("#fafafa")); p.stroke(win, hex("#bbbbbb"), 0.6)
        p.text("\(day)", 52.5, 3.4, size: 8, color: hex("#111111"), font: "HelveticaNeue-Medium")
    }
    let pip = p.ell(1.9, 0, -92.6)
    if dark { p.glow(pip, LM) } else { p.fill(pip, LM); p.stroke(pip, hex("#999999"), 0.4) }
    var marks: [CGPath] = []
    for i in 0..<12 { let a = CGFloat(i * 30)
        if i == 0 { marks += [p.rrect(-5, -75, 3.6, 13, 0.4), p.rrect(1.4, -75, 3.6, 13, 0.4)] }
        else if i % 3 == 0 { var t = CGAffineTransform(rotationAngle: a * .pi / 180)
            marks.append(CGPath(roundedRect: CGRect(x: -1.8, y: -75, width: 3.6, height: i == 3 ? 9 : 13), cornerWidth: 0.4, cornerHeight: 0.4, transform: &t)) }
        else { let q = p.P(69, a); marks.append(p.ell(4.6, q.x, q.y)) } }
    for m in marks { if dark { p.glow(m, LM) } else { p.fill(m, LM); p.stroke(m, DW, 0.7) } }
}

// ===== Pilot =====
private let LOG = { (v: CGFloat) -> CGFloat in log10(v / 10) * 360 }
private let PILOT_TICKS: [(CGFloat, Int)] = {
    var t: [(CGFloat, Int)] = []; var k = 100
    while k < 1000 { let v = CGFloat(k) / 10
        let l = (k % 50 == 0 || (k < 250 && k % 10 == 0)) ? 2 : ((k < 200 ? k % 10 == 0 : k < 500 ? k % 10 == 0 : k % 50 == 0) ? 1 : 0)
        t.append((v, l)); k += k < 200 ? 2 : k < 500 ? 5 : 10 }
    return t }()
func pilotStatic(_ p: Pen, dark: Bool) {
    let W = hex("#f2f2f2"), LM = dark ? hex("#d8e3a0") : hex("#d9c08c"), c = p.c
    if dark { p.circle(99.5, fill: hex("#060606")); p.circle(86, fill: hex("#020202")) }
    else {
        p.circle(99.6, fill: hex("#8a8a8a"))
        for i in 0..<120 { let q = p.P(98.2, CGFloat(i * 3)); p.at(q.x, q.y) { p.capDisc(1.45) } }   // beaded edge
        p.radial(96.4, [(0.86, "#d9d0b6"), (0.95, "#efe8d4"), (1, "#cfc6ac")]); p.circle(96.4, stroke: hex("#777777"), sw: 0.3)
        let OA = { (v: CGFloat) in LOG(v) - LOG(40) }, IA = { (v: CGFloat) in LOG(v) - LOG(60) }
        for (v, l) in PILOT_TICKS { p.tick(86.6, l == 2 ? 89.6 : l == 1 ? 88.6 : 87.8, OA(v), l == 2 ? 0.45 : l == 1 ? 0.32 : 0.2, hex("#222222")) }
        for v in [10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95] {
            let a = OA(CGFloat(v)), q = p.P(92.6, a); p.text("\(v)", q.x, q.y, size: 4.4, color: hex("#1a1a1a"), rot: a, dy: 1.6) }
        p.circle(86.2, fill: hex("#0b0b0c"), stroke: hex("#3a3a3a"), sw: 0.4)
        for (v, l) in PILOT_TICKS { let a = IA(v)
            p.tick(85.8, l == 2 ? 83 : l == 1 ? 83.8 : 84.6, a, l == 2 ? 0.4 : l == 1 ? 0.28 : 0.18, W)
            if l == 2 { p.tick(78.4, 77.2, a, 0.3, W) } }
        p.circle(78.5, stroke: W.copy(alpha: 0.8)!, sw: 0.25)
        for v in [10,11,12,13,14,15,16,17,18,19,20,25,30,35,40,45,50,55,65,70,75,80,85,90,95] {
            let a = IA(CGFloat(v)), an = (a.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            if an > 356 || (an > 276 && an < 308) { continue }
            let q = p.P(80.9, a); p.text("\(v)", q.x, q.y, size: 3.5, color: W, rot: a, dy: 1.25) }
        for t in [70,80,90,100,110,120,150,180,210,240,270,300,360,420,480,540] {
            var v = CGFloat(t); while v >= 100 { v /= 10 }
            let a = IA(v), q = p.P(75.2, a); p.text(String(format: "%d:%02d", t / 60, t % 60), q.x, q.y, size: 3.3, color: W, rot: a, dy: 1.2) }
        for (s, a) in [("STAT", -60.0), ("NAUT.", -74.0)] as [(String, CGFloat)] { let q = p.P(80.9, a); p.text(s, q.x, q.y, size: 3.3, color: W, rot: a, dy: 1.25, kern: 0.3) }
        for a in [-54.5, -80.5] as [CGFloat] { p.rot(a) { p.fill(p.poly([(0, -84.8), (-1.2, -82.8), (1.2, -82.8)]), W) } }
        p.radial(72.8, [(0, "#26272a"), (0.45, "#0e0e10"), (1, "#060607")], cx: 0.4, cy: 0.3, rr: 0.8); p.circle(72.8, stroke: W, sw: 0.3)
        for i in 0..<300 { let m5 = i % 25 == 0, m = i % 5 == 0; p.tick(72.6, m5 ? 69.2 : m ? 70.2 : 71.3, CGFloat(i) * 1.2, m5 ? 0.5 : m ? 0.35 : 0.18, W) }
        p.circle(69, stroke: W.copy(alpha: 0.7)!, sw: 0.22)
        for i in 1..<12 { let a = CGFloat(i * 30), q = p.P(65.6, a); p.text("\(i * 5)", q.x, q.y, size: 3.4, color: W, rot: a, dy: 1.2) }
        let sw = W.copy(alpha: 0.85)!
        for (s, a, r) in [("SWISS", 197.0, 17.0), ("MADE", 163.0, -17.0)] as [(String, CGFloat, CGFloat)] { let q = p.P(61.5, a); p.text(s, q.x, q.y, size: 2.6, color: sw, rot: r, dy: 0.9, kern: 0.6) }
        p.text("KM", 5.2, -73.6, size: 3, color: W)
        let box = CGPath(rect: CGRect(x: -4.4, y: -70.6, width: 8.8, height: 4.4), transform: nil); p.fill(box, hex("#0b0b0c")); p.stroke(box, W, 0.35)
        p.text("MPH", 0, -67.1, size: 3.2, color: W, font: "HelveticaNeue-Bold")
        pilotWings(p)
        p.text("PILOT", 0, -19.5, size: 4, color: sw, kern: 2)
    }
    let tri = p.poly([(0, -86), (-2.6, -77), (2.6, -77)])
    if dark { p.glow(tri, LM) } else { p.fill(tri, W) }
    // (large gilt hour numerals omitted: no numerals in the screensaver, per Tom)
    if !dark {
        func sub(_ cx: CGFloat, _ cy: CGFloat, _ nums: [String], _ run: Bool) {
            p.at(cx, cy) {
                p.circle(17, fill: hex("#070707"), stroke: hex("#2a2a2a"), sw: 0.5)
                var r: CGFloat = 1.5; while r < 16.5 { p.circle(r, stroke: CGColor(gray: 1, alpha: 0.05), sw: 0.12); r += 0.7 }
                let n = run ? 60 : nums.count * (nums.count > 6 ? 2 : 5)
                for i in 0..<n { let M = i % (n / nums.count) == 0; p.tick(16.4, M ? 13.8 : 15, CGFloat(i) * 360 / CGFloat(n), M ? 0.45 : 0.25, W) }
                for (i, t) in nums.enumerated() { let q = p.P(10, CGFloat(i) * 360 / CGFloat(nums.count)); p.text(t, q.x, q.y + 1.4, size: nums.count > 6 ? 3.4 : 4.2, color: W) }
            }
        }
        sub(-36, 0, ["60","10","20","30","40","50"], true); sub(36, 0, ["30","5","10","15","20","25"], false); sub(0, 36, ["12","1","2","3","4","5","6","7","8","9","10","11"], false)
        for (x, y) in [(36, 0), (0, 36)] as [(CGFloat, CGFloat)] {
            p.shadow(0, pilotSubHand(p), CGColor(gray: 0, alpha: 0.65), tx: x, ty: y)
            p.at(x, y) { p.fill(pilotSubHand(p), W) } }
        c.saveGState(); c.addEllipse(in: p.disc(76.4)); c.clip()
        c.drawLinearGradient(CGGradient(colorsSpace: RGB, colors: [CGColor(gray: 1, alpha: 0.09), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 0.45])!,
                             start: CGPoint(x: -76.4, y: -76.4), end: CGPoint(x: 76.4, y: 76.4), options: [.drawsAfterEndLocation]); c.restoreGState()
    }
}
private func pilotSubHand(_ p: Pen) -> CGPath { let m = CGMutablePath(); m.addPath(p.poly([(-0.5, 3), (-0.3, -14), (0.3, -14), (0.5, 3)])); m.addPath(p.ell(1.4)); return m }

// ===== per-frame hands =====
func specialHands(_ p: Pen, _ f: Face, dark: Bool, date: Date) {
    let a = handAngles(date), subS = CGFloat(Calendar.current.component(.second, from: date) * 6)
    switch f {
    case .chrono:
        if dark {
            for (deg, len, tw) in [(a.h, 50.0, 1.1), (a.m, 76.0, 0.9)] as [(CGFloat, CGFloat, CGFloat)] {
                p.rot(deg) { p.fill(p.poly([(-tw*1.9, 8), (-tw, -len+2.5), (0, -len), (tw, -len+2.5), (tw*1.9, 8)]), hexA("#0b0c0c", 0.6))
                    p.glow(p.poly([(-tw*0.45, -len*0.3), (-tw*0.4, -len+5), (tw*0.4, -len+5), (tw*0.45, -len*0.3)]), CDG) } }
            if SHOW_SECONDS { p.rot(a.s) { p.fill(p.poly([(-0.4, 16), (-0.2, -82), (0.2, -82), (0.4, 16)]), hexA("#0b0c0c", 0.6))
                p.glow(p.poly([(0, -71), (1.6, -66), (0, -61), (-1.6, -66)]), CDG) } }
            return
        }
        let sh = CGColor(gray: 0, alpha: 0.6)
        // running seconds subdial at 9
        let sub = CGMutablePath(); sub.addPath(chronoSubHand(p)); sub.addPath(p.ell(1.6))
        p.shadow(subS, sub, sh, tx: -38, ty: 0)
        p.at(-38, 0) { p.rot(subS) { p.fill(sub, CW) }; p.fill(p.ell(0.7), hex("#777777")) }
        for (deg, len, w, tw) in [(a.h, 50.0, 1.9, 2.1), (a.m, 76.0, 1.6, 1.7)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            let body = p.poly([(-w, 8), (-tw, -len+2.5), (0, -len), (tw, -len+2.5), (w, 8)])
            p.shadow(deg, body, sh)
            p.rot(deg) { p.fill(body, CW); p.stroke(body, CGColor(gray: 0, alpha: 0.35), 0.25)
                p.fill(p.poly([(-tw*0.45, -len*0.3), (-tw*0.4, -len+5), (tw*0.4, -len+5), (tw*0.45, -len*0.3)]), CLM) } }
        if SHOW_SECONDS {
            let needle = p.poly([(-0.5, 16), (-0.25, -82), (0.25, -82), (0.5, 16)]), dia = p.poly([(0, -71), (1.6, -66), (0, -61), (-1.6, -66)])
            let sil = CGMutablePath(); sil.addPath(needle); sil.addPath(dia); sil.addPath(p.ell(2.2))
            p.shadow(a.s, sil, sh)
            p.rot(a.s) { p.fill(needle, CW); p.fill(dia, CLM); p.stroke(dia, CW, 0.4); p.fill(p.ell(2.2), CW) } }
        p.shadow(0, p.ell(4.2), sh); p.capDisc(4.2); p.circle(4.2, stroke: CGColor(gray: 0, alpha: 0.4), sw: 0.3)
        p.circle(2.2, fill: hex("#cfcfcf")); p.circle(0.9, fill: hex("#888888"))
    case .diver:
        let LM = dark ? hex("#cfe8b0") : hex("#dfe9c8"), sh = CGColor(gray: 0, alpha: 0.6)
        func skel(_ deg: CGFloat, _ len: CGFloat, round: Bool) {
            let w: CGFloat = 3.4, shape = CGMutablePath()
            if round {
                let y = -len + 8.6, cy = y - 3.55
                shape.addLines(between: [CGPoint(x: -1, y: 6), CGPoint(x: -1, y: -len*0.3), CGPoint(x: -2.6, y: -len*0.34), CGPoint(x: -2.6, y: y)])
                shape.addArc(center: CGPoint(x: 0, y: cy), radius: 4.4, startAngle: atan2(3.55, -2.6), endAngle: atan2(3.55, 2.6) + 2 * .pi, clockwise: false)
                shape.addLines(between: [CGPoint(x: 2.6, y: y), CGPoint(x: 2.6, y: -len*0.34), CGPoint(x: 1, y: -len*0.3), CGPoint(x: 1, y: 6)]); shape.closeSubpath()
            } else { shape.addPath(p.poly([(-1, 6), (-1, -len*0.25), (-w, -len*0.3), (-w, -len+9), (0, -len), (w, -len+9), (w, -len*0.3), (1, -len*0.25), (1, 6)])) }
            let lume = round ? p.ell(2.9, 0, -len + 5.3) : p.poly([(0, -len+2.2), (w-1, -len+8.4), (-w+1, -len+8.4)])
            if dark { p.rot(deg) { p.fill(shape, hexA("#0b0e14", 0.5)); p.glow(lume, LM) }; return }
            p.shadow(deg, shape, sh)
            p.rot(deg) { p.fill(shape, DW); p.stroke(shape, CGColor(gray: 0, alpha: 0.35), 0.25)
                let hollow = round ? CGPath(rect: CGRect(x: -1.4, y: -len+9.6, width: 2.8, height: len*0.66-11), transform: nil)
                                   : p.poly([(-w+1.1, -len*0.3+1.5), (-w+1.1, -len+9.6), (w-1.1, -len+9.6), (w-1.1, -len*0.3+1.5)])
                p.fill(hollow, hex("#18223a")); p.fill(lume, LM) }
        }
        skel(a.h, 46, round: true); skel(a.m, 72, round: false)
        if SHOW_SECONDS {
            if dark { p.rot(a.s) { p.glow(p.ell(2.2, 0, -60), LM) } }
            else {
                let needle = p.poly([(-0.45, 18), (-0.22, -78), (0.22, -78), (0.45, 18)])
                let sil = CGMutablePath(); sil.addPath(needle); sil.addPath(p.ell(2.4, 0, -60)); sil.addPath(p.ell(2.2))
                p.shadow(a.s, sil, sh)
                p.rot(a.s) { p.fill(needle, DW); p.fill(p.poly([(-0.24, -78), (-0.2, -66), (0.2, -66), (0.24, -78)]), hex("#e3261f"))
                    p.fill(p.ell(2.4, 0, -60), LM); p.stroke(p.ell(2.4, 0, -60), DW, 0.6); p.fill(p.ell(2.2), DW) } } }
        if !dark { p.shadow(0, p.ell(3.8), sh); p.capDisc(3.8); p.circle(3.8, stroke: CGColor(gray: 0, alpha: 0.4), sw: 0.3); p.circle(1.1, fill: hex("#888888")) }
    case .pilot:
        let LM = dark ? hex("#d8e3a0") : hex("#d9c08c"), W = hex("#f2f2f2"), sh = CGColor(gray: 0, alpha: 0.65)
        if !dark { p.shadow(subS, pilotSubHand(p), sh, tx: -36, ty: 0); p.at(-36, 0) { p.rot(subS) { p.fill(pilotSubHand(p), W) } } }
        for (deg, len, w) in [(a.h, 48.0, 2.6), (a.m, 72.0, 2.3)] as [(CGFloat, CGFloat, CGFloat)] {
            if dark { p.rot(deg) { p.glow(p.poly([(-w*0.45, -len*0.25), (-w*0.4, -len+3), (w*0.4, -len+3), (w*0.45, -len*0.25)]), LM) }; continue }
            let body = p.poly([(-w*0.7, 10), (-w, -len*0.2), (-w*0.85, -len+2), (0, -len), (w*0.85, -len+2), (w, -len*0.2), (w*0.7, 10)])
            p.shadow(deg, body, sh)
            p.rot(deg) { p.fill(body, hex("#3a2f22")); p.fill(p.poly([(-w*0.6, -len*0.18), (-w*0.5, -len+3.5), (0, -len+1.6), (w*0.5, -len+3.5), (w*0.6, -len*0.18)]), LM) } }
        if dark { return }
        if SHOW_SECONDS {
            let needle = CGMutablePath(); needle.addPath(p.poly([(-0.45, 16), (-0.2, -84), (0.2, -84), (0.45, 16)])); needle.addPath(p.ell(2))
            p.shadow(a.s, needle, sh); p.rot(a.s) { p.fill(needle, W) } }
        p.shadow(0, p.ell(4), sh); p.capDisc(4); p.circle(4, stroke: CGColor(gray: 0, alpha: 0.45), sw: 0.3); p.circle(1.2, fill: hex("#888888"))
    }
}

/// Generic pilot wings (original design, no emblem or letters): swept feathered wings + plain shield, thin aged-gold line.
func pilotWings(_ p: Pen) {
    let wing = CGMutablePath()
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    wing.move(to: pt(3.2, -33.5)); wing.addCurve(to: pt(25, -28.5), control1: pt(9, -37), control2: pt(17, -35.5)); wing.addLine(to: pt(20, -29.2))
    wing.addQuadCurve(to: pt(16.5, -29.6), control: pt(18.5, -27.6)); wing.addQuadCurve(to: pt(12.5, -29.8), control: pt(14.5, -27.4))
    wing.addQuadCurve(to: pt(8.5, -30), control: pt(10.5, -27.6)); wing.addQuadCurve(to: pt(4, -29.8), control: pt(6.5, -28)); wing.closeSubpath()
    wing.move(to: pt(5, -32)); wing.addCurve(to: pt(21, -29.8), control1: pt(10, -34.2), control2: pt(15, -33.4))
    wing.move(to: pt(5, -31)); wing.addCurve(to: pt(17, -30.2), control1: pt(9, -32), control2: pt(13, -31.6))
    let shield = CGMutablePath()
    shield.move(to: pt(-3.4, -35)); shield.addLine(to: pt(3.4, -35)); shield.addLine(to: pt(3.4, -31.5))
    shield.addQuadCurve(to: pt(0, -26.6), control: pt(3.4, -28)); shield.addQuadCurve(to: pt(-3.4, -31.5), control: pt(-3.4, -28)); shield.closeSubpath()
    let inner = CGMutablePath(); inner.move(to: pt(-2.4, -34)); inner.addLine(to: pt(2.4, -34)); inner.addLine(to: pt(2.4, -31.6)); inner.addQuadCurve(to: pt(0, -28), control: pt(2.4, -29.1))
    let col = hexA("#b39a68", 0.8), c = p.c
    c.saveGState(); c.setLineJoin(.round)
    p.stroke(wing, col, 0.35)
    var m = CGAffineTransform(scaleX: -1, y: 1); if let l = wing.copy(using: &m) { p.stroke(l, col, 0.35) }
    p.fill(shield, hex("#0c0c0d")); p.stroke(shield, col, 0.35); p.stroke(inner, col, 0.35)
    c.restoreGState()
}
