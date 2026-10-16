import AppKit

struct Palette { let name: String; let dial, ink, idx, sec: CGColor }
func hex(_ s: String) -> CGColor {
    var t = String(s.dropFirst())
    if t.count == 3 { t = t.map { "\($0)\($0)" }.joined() }
    var v: UInt64 = 0; Scanner(string: t).scanHexInt64(&v)
    return CGColor(srgbRed: CGFloat((v >> 16) & 255)/255, green: CGFloat((v >> 8) & 255)/255, blue: CGFloat(v & 255)/255, alpha: 1)
}
// Copied from DIALS in index.html: [dial, ink(hands), idx(ticks), sec]
let PALETTES: [Palette] = [
 ("White","#ffffff","#111","#cfcfcf","#e8452c"),("Turquoise","#d5efef","#10302f","#9fc9c8","#e8452c"),
 ("Glacier","#e3edf2","#14232b","#b3c6cf","#e8452c"),("Ocean","#1f4e6b","#f2f5f7","#5f88a0","#ffb02e"),
 ("Tennis","#dfe86a","#1d2108","#b2ba3c","#1f5fd1"),("Signal Blue","#1e5bd6","#fff","#6c95e6","#ffcf2e"),
 ("Salmon","#f6a48f","#2a120c","#e07f69","#fff"),("Yellow","#f7d33a","#1d1700","#d4ad18","#e8452c"),
 ("Beige","#ece3d3","#2b241a","#c9bca6","#e8452c"),("Pistachio","#cfe3c0","#18240f","#a3be8f","#e8452c"),
 ("Lavender","#d9d2f0","#1c1630","#ada3d4","#e8452c"),("Rose","#f4cfd6","#2c1218","#d9a2ad","#c8243c"),
 ("Sky Blue","#bfe0f6","#0e2433","#8dbfe0","#e8452c"),("Cream","#f7f1e1","#29241a","#d8cfb6","#e8452c"),
 ("Slate","#3b4248","#eef0f2","#6b747c","#ff8a3d"),("Noir","#1b1b1b","#f2f2f2","#3c3c3c","#ff5a36"),
].map { Palette(name: $0.0, dial: hex($0.1), ink: hex($0.2), idx: hex($0.3), sec: hex($0.4)) }
let NOIR = PALETTES.count - 1

// ---- Subtle matte style (Tom's reference photo); svg units, dial radius R = 100 ----
import CoreText

enum Prim {
    case minuteTick                                   // 0.96 x 6.2, outer end 91.5
    case hourBar(quarter: Bool)                       // pale pill 4.4x17 / 4.2x14, wide soft groove (46%)
    case hand(tip: CGFloat, tail: CGFloat, bw: CGFloat, tw: CGFloat)   // slim taper, rounded tip
    case second                                       // pale, slim, short counterweight
    case cap
    case numeral(Int)                                 // hour numeral (explosion piece)
    case wedge(r: CGFloat, a0: CGFloat, a1: CGFloat)  // dial shard (explosion)
}
let HOUR = Prim.hand(tip: 57, tail: 2.5, bw: 2.1, tw: 1.35)
let MINUTE = Prim.hand(tip: 88, tail: 2.5, bw: 1.75, tw: 1.0)
let DIAL_R: CGFloat = 100
let NUM_R: CGFloat = 61, NUM_SIZE: CGFloat = 9.2, MIN_NUM_R: CGFloat = 96.6, MIN_NUM_SIZE: CGFloat = 4.9

private let SRGB = CGColorSpace(name: CGColorSpace.sRGB)!
private func grad(_ c: [String], _ l: [CGFloat]) -> CGGradient { CGGradient(colorsSpace: SRGB, colors: c.map(hex) as CFArray, locations: l)! }
struct Style {
    let light: Bool, dial: CGColor, part: CGGradient, groove: CGGradient, edge: CGColor
    let shadowAlpha: CGFloat, num: CGColor, minNum: CGColor, tick: CGColor, sec: CGColor
}
func luminance(_ c: CGColor) -> CGFloat { let p = c.converted(to: SRGB, intent: .defaultIntent, options: nil)?.components ?? [0,0,0]; return 0.299*p[0] + 0.587*p[1] + 0.114*p[2] }
private let PALE = grad(["#d4d4d4","#f1f1f1","#ebebeb","#cbcbcb"], [0, 0.35, 0.7, 1])
private let PALE_G = grad(["#a6a6a6","#c8c8c8","#e8e8e8"], [0, 0.5, 1])
private let DARK = grad(["#2e2e2e","#555555","#4a4a4a","#262626"], [0, 0.35, 0.7, 1])
private let DARK_G = grad(["#1c1c1c","#333333","#4d4d4d"], [0, 0.5, 1])
let CAPG = grad(["#e2e2e2","#9c9c9c"], [0, 1])
let LUME_PART = grad(["#0c1113","#141b1e","#0a0e10"], [0, 0.5, 1])
let LUME_STYLE = Style(light: false, dial: hex("#020405"), part: LUME_PART, groove: LUME_PART, edge: hex("#1c2a30"), shadowAlpha: 0,
                       num: hex("#2ee6f0"), minNum: hex("#1a5560"), tick: hex("#1a5560"), sec: hex("#0b1417"))
func style(_ p: Palette) -> Style {
    if LUME_ACTIVE { return LUME_STYLE }
    let light = luminance(p.dial) > 0.55
    return Style(light: light, dial: p.dial, part: light ? DARK : PALE, groove: light ? DARK_G : PALE_G,
                 edge: CGColor(gray: 0, alpha: light ? 0.28 : 0.35), shadowAlpha: light ? 0.35 : 0.6,
                 num: light ? p.ink : hex("#ececec"), minNum: light ? p.ink.copy(alpha: 0.5)! : hex("#9a9a9a"),
                 tick: light ? p.ink.copy(alpha: 0.4)! : hex("#777777"), sec: light ? p.ink : hex("#e6e6e6"))
}

// Numeral font: bundled ClockNum.ttf (digits subset of Michroma, OFL), fallback Futura.
final class FontToken {}
let NUM_FONT_NAME: String = {
    let urls = [Bundle(for: FontToken.self).url(forResource: "ClockNum", withExtension: "ttf"), URL(fileURLWithPath: "ClockNum.ttf")]
    for case let u? in urls where FileManager.default.fileExists(atPath: u.path) {
        if let d = (CTFontManagerCreateFontDescriptorsFromURL(u as CFURL) as? [CTFontDescriptor])?.first,
           let n = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String {
            CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil); return n }
    }
    return "Futura-Medium"
}()
private var fontCache: [CGFloat: CTFont] = [:]
private func numFont(_ size: CGFloat) -> CTFont { if let f = fontCache[size] { return f }; let f = CTFontCreateWithName(NUM_FONT_NAME as CFString, size, nil); fontCache[size] = f; return f }
/// Text centred at origin in svg (y-down) space.
func drawText(_ ctx: CGContext, _ s: String, size: CGFloat, color: CGColor) {
    let font = numFont(size)
    let attr = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color])
    let line = CTLineCreateWithAttributedString(attr)
    let w = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)), capH = CTFontGetCapHeight(font)
    ctx.saveGState(); ctx.scaleBy(x: 1, y: -1); ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: -w/2, y: -capH/2); CTLineDraw(line, ctx); ctx.restoreGState()
}

private func pill(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath { CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: w/2, cornerHeight: w/2, transform: nil) }
private func fillGrad(_ ctx: CGContext, _ path: CGPath, _ g: CGGradient, halfW: CGFloat) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(g, start: CGPoint(x: -halfW, y: 0), end: CGPoint(x: halfW, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}
/// slim tapered shape from y=from (near centre, half-width bw) to y=-tip (half-width tw), round ends.
private func taper(_ from: CGFloat, _ tip: CGFloat, _ bw: CGFloat, _ tw: CGFloat) -> CGPath {
    let p = CGMutablePath(), ty = -(tip - tw)
    p.move(to: CGPoint(x: -bw, y: from)); p.addLine(to: CGPoint(x: -tw, y: ty))
    p.addArc(center: CGPoint(x: 0, y: ty), radius: tw, startAngle: .pi, endAngle: 0, clockwise: false)
    p.addLine(to: CGPoint(x: bw, y: from))
    p.addArc(center: CGPoint(x: 0, y: from), radius: bw, startAngle: 0, endAngle: .pi, clockwise: false)
    p.closeSubpath(); return p
}

/// Draw one part in svg space (y down, already rotated). Shadow handled by caller.
func drawPrim(_ ctx: CGContext, _ p: Prim, _ st: Style) {
    switch p {
    case .minuteTick:
        ctx.setFillColor(LUME_ACTIVE ? LUME_TICK : st.tick); ctx.addPath(CGPath(roundedRect: CGRect(x: -0.48, y: -91.5, width: 0.96, height: 6.2), cornerWidth: 0.3, cornerHeight: 0.3, transform: nil)); ctx.fillPath()
    case .hourBar(let q):
        let w: CGFloat = q ? 4.4 : 4.2, L: CGFloat = q ? 17 : 14, y: CGFloat = q ? -92 : -91, gw = w * (LUME_ACTIVE ? 0.36 : 0.46)
        let body = pill(-w/2, y, w, L)
        fillGrad(ctx, body, st.part, halfW: w/2)
        ctx.addPath(body); ctx.setStrokeColor(st.edge); ctx.setLineWidth(0.25); ctx.strokePath()
        let gp = pill(-gw/2, y + 2, gw, L - 4)
        if LUME_ACTIVE { lumeFill(ctx, gp) } else { fillGrad(ctx, gp, st.groove, halfW: gw/2) }
    case let .hand(tip, tail, bw, tw):
        let body = taper(tail, tip, bw, tw)
        fillGrad(ctx, body, st.part, halfW: bw)
        ctx.addPath(body); ctx.setStrokeColor(st.edge); ctx.setLineWidth(0.25); ctx.strokePath()
        let gf: CGFloat = LUME_ACTIVE ? 0.36 : 0.45
        let gp = taper(-tip * 0.28, tip - tw - 3 + tw*gf, bw*gf, tw*gf)
        if LUME_ACTIVE { lumeFill(ctx, gp) } else { fillGrad(ctx, gp, st.groove, halfW: bw*0.45) }
    case .second:
        ctx.setFillColor(st.sec); ctx.addPath(secondPath()); ctx.fillPath()
        ctx.fillEllipse(in: CGRect(x: -2.6, y: -2.6, width: 5.2, height: 5.2))
        if LUME_ACTIVE { lumeFill(ctx, CGPath(roundedRect: CGRect(x: -0.17, y: -84, width: 0.34, height: 70), cornerWidth: 0.17, cornerHeight: 0.17, transform: nil), glow: 0.6, core: LUME_SEC); return }
        // subtle groove along the counterweight paddle
        let g = CGMutablePath(); g.move(to: CGPoint(x: -0.22, y: 8)); g.addLine(to: CGPoint(x: -0.5, y: 21.5))
        g.addArc(center: CGPoint(x: 0, y: 21.5), radius: 0.5, startAngle: .pi, endAngle: 0, clockwise: true); g.addLine(to: CGPoint(x: 0.22, y: 8)); g.closeSubpath()
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.18)); ctx.addPath(g); ctx.fillPath()
    case .cap:
        func disc(_ r: CGFloat) -> CGRect { CGRect(x: -r, y: -r, width: 2*r, height: 2*r) }
        func radial(_ r: CGFloat) { ctx.saveGState(); ctx.addEllipse(in: disc(r)); ctx.clip()
            ctx.drawRadialGradient(CAPG, startCenter: CGPoint(x: -0.16*r, y: -0.24*r), startRadius: 0, endCenter: CGPoint(x: -0.16*r, y: -0.24*r), endRadius: r*1.4, options: [.drawsAfterEndLocation]); ctx.restoreGState() }
        if LUME_ACTIVE { ctx.setFillColor(hex("#06090a")); ctx.fillEllipse(in: disc(5.4)); ctx.setLineWidth(0.5); ctx.setStrokeColor(hex("#1c2a30")); ctx.strokeEllipse(in: disc(5.4))
            ctx.setLineWidth(0.4); ctx.setStrokeColor(hex("#15343a")); ctx.strokeEllipse(in: disc(2.4)); return }
        radial(5.4); ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.35)); ctx.setLineWidth(0.3); ctx.strokeEllipse(in: disc(5.4))
        ctx.setFillColor(hex("#d8d8d8")); ctx.fillEllipse(in: disc(3.9)); ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.25)); ctx.strokeEllipse(in: disc(3.9))
        radial(2.3); ctx.setFillColor(hex("#8d8d8d")); ctx.fillEllipse(in: disc(1))
    case .numeral(let n):
        drawText(ctx, String(n), size: NUM_SIZE, color: st.num)
    case let .wedge(r, a0, a1):
        ctx.setFillColor(st.dial); ctx.move(to: .zero); ctx.addArc(center: .zero, radius: r, startAngle: a0, endAngle: a1, clockwise: false); ctx.closePath(); ctx.fillPath()
    }
}
/// Crisp shadow (static parts), light from top-right: dx -1.2, dy +1.8 (down-left), blur ~0.25, svg units scaled by k. Offset is in device space, so it never rotates with the hands.
func withShadow(_ ctx: CGContext, _ k: CGFloat, _ st: Style, _ body: () -> Void) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: -1.2*k, height: -1.8*k), blur: 0.25*k, color: CGColor(gray: 0, alpha: st.shadowAlpha))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil); body(); ctx.endTransparencyLayer()
    ctx.restoreGState()
}
var SHADOWS_ON = true   // test hook
// ---- Lume: glowing cyan grooves (reference: #2ee6f0 core with soft bloom), dim teal minute ticks ----
var LUME_ACTIVE = false
let LUME_CORE = hex("#2ee6f0"), LUME_HALO = hex("#2ee6f0").copy(alpha: 0.85)!, LUME_TICK = hex("#1a5560"), LUME_SEC = hex("#26b4c0").copy(alpha: 0.85)!, LUME_HOT = hex("#9ffaff")
/// Fill a groove with glowing lume: two soft blooms (blur scales with the current zoom) plus a crisp core.
func lumeFill(_ ctx: CGContext, _ path: CGPath, glow: CGFloat = 1, core: CGColor = LUME_CORE) {
    let t = ctx.ctm, k = hypot(t.a, t.b)   // device px per svg unit
    for (blur, a) in [(3.2, 0.9), (1.0, 1.0)] as [(CGFloat, CGFloat)] {
        ctx.saveGState(); ctx.setShadow(offset: .zero, blur: blur * k * glow, color: LUME_HALO.copy(alpha: 0.85 * a)!)
        ctx.addPath(path); ctx.setFillColor(core); ctx.fillPath(); ctx.restoreGState()
    }
    ctx.addPath(path); ctx.setFillColor(core); ctx.fillPath()
    if core === LUME_CORE {   // brighter centre stripe
        let b = path.boundingBoxOfPath; ctx.saveGState(); ctx.addPath(path); ctx.clip()
        let g = CGGradient(colorsSpace: SRGB, colors: [LUME_CORE, LUME_HOT, LUME_CORE] as CFArray, locations: [0, 0.5, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: b.minX, y: 0), end: CGPoint(x: b.maxX, y: 0), options: []); ctx.restoreGState() }
}
let SHADOW_DX: CGFloat = -1.2, SHADOW_DY: CGFloat = 1.8   // svg units (y down): down-left
/// Flat dark silhouette of a moving part (for crisp shadows).
func drawSilhouette(_ ctx: CGContext, _ p: Prim, _ c: CGColor) {
    ctx.setFillColor(c)
    switch p {
    case let .hand(tip, tail, bw, tw): ctx.addPath(taper(tail, tip, bw, tw))
    case .second:
        ctx.addPath(secondPath()); ctx.addEllipse(in: CGRect(x: -2.6, y: -2.6, width: 5.2, height: 5.2))
    case .cap: ctx.addEllipse(in: CGRect(x: -5.4, y: -5.4, width: 10.8, height: 10.8))
    default: return
    }
    ctx.fillPath()
}
/// Second hand outline: slim needle to 0.91R plus a counterweight paddle (0.04R..0.24R) widening
/// gently from 1.5 to 2.7 units with a rounded end; one continuous shape.
func secondPath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -0.45, y: 0)); p.addLine(to: CGPoint(x: -0.2, y: -91)); p.addLine(to: CGPoint(x: 0.2, y: -91))
    p.addLine(to: CGPoint(x: 0.45, y: 0)); p.addLine(to: CGPoint(x: 0.75, y: 4)); p.addLine(to: CGPoint(x: 1.35, y: 22.6))
    p.addArc(center: CGPoint(x: 0, y: 22.6), radius: 1.35, startAngle: 0, endAngle: .pi, clockwise: false)
    p.addLine(to: CGPoint(x: -0.75, y: 4)); p.closeSubpath(); return p
}
func handAngles(_ date: Date) -> (h: CGFloat, m: CGFloat, s: CGFloat) {
    let c = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
    let s = Double(c.second!) + Double(c.nanosecond!)/1e9, m = Double(c.minute!) + s/60, h = Double(c.hour! % 12) + m/60
    return (CGFloat(h*30), CGFloat(m*6), CGFloat(s*6))
}
private func rot(_ ctx: CGContext, _ deg: CGFloat, _ f: () -> Void) { ctx.saveGState(); ctx.rotate(by: deg * .pi/180); f(); ctx.restoreGState() }
func numeralPos(_ n: Int) -> CGPoint { let a = CGFloat(n) * .pi / 6; return CGPoint(x: sin(a) * NUM_R, y: -cos(a) * NUM_R) }

/// Fine leather-like grain tile (white noise at ~7% alpha), drawn in device space on the Noir dial.
let GRAIN: CGImage = {
    let n = 192; var px = [UInt8](repeating: 0, count: n*n*4); var seed: UInt64 = 0x9E3779B97F4A7C15
    for i in 0..<(n*n) { seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let v = Int(seed >> 56)   // fine grain: faint light and dark specks (premultiplied)
        if v & 1 == 0 { let a = UInt8(v * 9 / 255); px[i*4] = a; px[i*4+1] = a; px[i*4+2] = a; px[i*4+3] = a }
        else { px[i*4+3] = UInt8(v * 16 / 255) } }
    let ctx = CGContext(data: &px, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n*4, space: SRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return ctx.makeImage()!
}()

func drawClock(_ ctx: CGContext, center c: CGPoint, k: CGFloat, pal: Palette, date: Date, alpha: CGFloat = 1, scale: CGFloat = 1) {
    let st = style(pal), kk = k * scale
    ctx.saveGState(); ctx.setAlpha(alpha); ctx.setShouldAntialias(true)
    if alpha < 1 { ctx.beginTransparencyLayer(auxiliaryInfo: nil) }
    // dial (device space so the grain stays fine at any size)
    let R = DIAL_R * kk, disc = CGRect(x: c.x - R, y: c.y - R, width: 2*R, height: 2*R)
    ctx.setFillColor(st.dial); ctx.fillEllipse(in: disc)
    if pal.name == "Noir" && !LUME_ACTIVE { ctx.saveGState(); ctx.addEllipse(in: disc); ctx.clip()
        ctx.draw(GRAIN, in: CGRect(x: 0, y: 0, width: 192, height: 192), byTiling: true); ctx.restoreGState() }
    ctx.translateBy(x: c.x, y: c.y); ctx.scaleBy(x: kk, y: -kk)    // sub-pixel origin, y down
    for i in 0..<60 where i % 5 != 0 { rot(ctx, CGFloat(i*6)) { drawPrim(ctx, .minuteTick, st) } }
    // outer minute numerals intentionally omitted (Tom)
    do {   // markers and numerals sit flat on the dial: no shadow of their own
        for i in 0..<12 { rot(ctx, CGFloat(i*30)) { drawPrim(ctx, .hourBar(quarter: i % 3 == 0), st) } }
        // hour numerals removed from the screensaver (Tom)
    }
    let a = handAngles(date)
    // Crisp per-part shadows in stacking order; the offset is applied before rotation, so it stays fixed on screen.
    // multiply-blended dark grey: the shadow becomes a darker tone of whatever it falls on
    let sc = CGColor(gray: 0, alpha: st.light ? 0.35 : 0.6)   // near-black multiply: can only darken
    func shadowed(_ deg: CGFloat?, _ p: Prim) {
        ctx.saveGState(); ctx.setBlendMode(.multiply); ctx.translateBy(x: SHADOW_DX, y: SHADOW_DY)
        if let d = deg { ctx.rotate(by: d * .pi/180) }
        if SHADOWS_ON && !LUME_ACTIVE { drawSilhouette(ctx, p, sc) }; ctx.restoreGState()
        if let d = deg { rot(ctx, d) { drawPrim(ctx, p, st) } } else { drawPrim(ctx, p, st) }
    }
    shadowed(a.h, HOUR); shadowed(a.m, MINUTE); shadowed(a.s, .second); shadowed(nil, .cap)
    if alpha < 1 { ctx.endTransparencyLayer() }
    ctx.restoreGState()
}
