import AppKit

struct Particle { var prim: Prim; var pal: Int; var pos: CGPoint; var vel: CGVector; var ang: CGFloat; var spin: CGFloat }

/// Bouncing clock with corner-hit explosion. View points, y up.
final class BounceSim {
    enum Phase { case moving, exploding(t: Double), appearing(t: Double) }
    let size: CGSize
    var radius: CGFloat { size.height / 3 }             // diameter = 2/3 H
    var k: CGFloat { radius / DIAL_R }
    var speed: CGFloat { size.height * 30 / 1080 }      // ~30 px/s at 1080p
    var pos: CGPoint = .zero, vel: CGVector = .zero
    var pal = NOIR
    var phase: Phase = .moving
    var particles: [Particle] = []
    var corners = 0
    let cornerTol: CGFloat
    static let explodeDur = 1.8, appearDur = 0.6
    // Night dimming: after 3 min running, if 22:00-07:00 local, fade to 33% over ~10 s; fade back up by day.
    static let dimDelay = 180.0, dimLevel: CGFloat = 0.33, dimFade = 10.0
    var elapsed = 0.0
    var brightness: CGFloat = 1
    static func isNight(_ d: Date) -> Bool { let h = Calendar.current.component(.hour, from: d); return h >= 22 || h < 7 }
    var dimTarget: CGFloat = 1
    var prefLume = false        // user option (Screen Saver Options sheet)
    var autoNightLume = true    // lume switches on automatically when night dimming kicks in
    var lumeActive: Bool { prefLume || (autoNightLume && dimTarget < 1) }

    init(size: CGSize) {
        self.size = size
        cornerTol = max(3, size.height * 3 / 1080)
        respawn(newPalette: false)
    }
    func rnd(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat.random(in: a...b) }

    func respawn(newPalette: Bool) {
        let r = radius
        pos = CGPoint(x: rnd(r, size.width - r), y: rnd(r, size.height - r))
        var th = rnd(0, 2 * .pi)
        while abs(cos(th)) < 0.3 || abs(sin(th)) < 0.3 { th = rnd(0, 2 * .pi) }
        vel = CGVector(dx: cos(th) * speed, dy: sin(th) * speed)
        if newPalette { var n = pal; while n == pal { n = Int.random(in: 0..<PALETTES.count) }; pal = n }
    }

    /// Frame-rate independent: dt sub-stepped at 120 Hz; spikes (sleep, stalls) clamped to 0.1 s.
    func step(_ dt: Double, date: Date = Date()) {
        elapsed += dt
        dimTarget = (elapsed >= Self.dimDelay && Self.isNight(date)) ? Self.dimLevel : 1
        let rate = (1 - Self.dimLevel) / CGFloat(Self.dimFade) * CGFloat(min(dt, 0.1))
        brightness = brightness < dimTarget ? min(dimTarget, brightness + rate) : max(dimTarget, brightness - rate)
        var left = min(dt, 0.1)
        while left > 1e-9 { let d = min(left, 1.0/120); left -= d; sub(d, date) }
    }
    private func sub(_ dt: Double, _ date: Date) {
        switch phase {
        case .moving:
            let r = radius, d = CGFloat(dt)
            pos.x += vel.dx * d; pos.y += vel.dy * d
            var hitX = false, hitY = false
            if pos.x - r <= 0 { pos.x = 2*r - pos.x; vel.dx = abs(vel.dx); hitX = true }
            if pos.x + r >= size.width { pos.x = 2*(size.width - r) - pos.x; vel.dx = -abs(vel.dx); hitX = true }
            if pos.y - r <= 0 { pos.y = 2*r - pos.y; vel.dy = abs(vel.dy); hitY = true }
            if pos.y + r >= size.height { pos.y = 2*(size.height - r) - pos.y; vel.dy = -abs(vel.dy); hitY = true }
            if hitX || hitY {
                let dx = min(pos.x - r, size.width - r - pos.x), dy = min(pos.y - r, size.height - r - pos.y)
                if (hitX && hitY) || (hitX && dy <= cornerTol) || (hitY && dx <= cornerTol) { explode(date) }
            }
        case .exploding(let t):
            let g = -size.height * 1.1, d = CGFloat(dt)
            for i in particles.indices {
                particles[i].vel.dy += g * d
                particles[i].pos.x += particles[i].vel.dx * d; particles[i].pos.y += particles[i].vel.dy * d
                particles[i].ang += particles[i].spin * d
            }
            let nt = t + dt
            if nt >= Self.explodeDur { particles = []; respawn(newPalette: true); phase = .appearing(t: 0) } else { phase = .exploding(t: nt) }
        case .appearing(let t):
            phase = t + dt >= Self.appearDur ? .moving : .appearing(t: t + dt)
        }
    }

    func explode(_ date: Date) {
        corners += 1
        let p = PALETTES[pal], k = self.k, c = pos, H = size.height
        var parts: [Particle] = []
        func add(_ prim: Prim, rot: CGFloat, local: CGPoint, boost: CGFloat) {
            let off = CGPoint(x: local.x * k, y: -local.y * k)
            let len = max(hypot(off.x, off.y), 1), sp = rnd(0.6, 1.4) * H * boost
            let v = CGVector(dx: off.x/len*sp + rnd(-0.1, 0.1)*H, dy: off.y/len*sp + rnd(0.1, 0.5)*H)
            parts.append(Particle(prim: prim, pal: pal, pos: c, vel: v, ang: rot, spin: rnd(-240, 240)))
        }
        func around(_ deg: CGFloat, _ dist: CGFloat) -> CGPoint { let a = deg * .pi/180; return CGPoint(x: sin(a)*dist, y: -cos(a)*dist) }
        for i in 0..<12 {
            let a0 = CGFloat(i)/12 * 2 * .pi, a1 = CGFloat(i+1)/12 * 2 * .pi, mid = (a0 + a1)/2
            add(.wedge(r: DIAL_R, a0: a0, a1: a1), rot: 0, local: CGPoint(x: cos(mid)*50, y: sin(mid)*50), boost: 0.35)
        }
        for i in 0..<60 { let d = CGFloat(i*6)
            add(i % 5 == 0 ? .hourBar(quarter: i % 15 == 0) : .minuteTick, rot: d, local: around(d, 85), boost: 0.5) }
        let a = handAngles(date)
        add(HOUR, rot: a.h, local: around(a.h, 21), boost: 0.3)
        add(MINUTE, rot: a.m, local: around(a.m, 37), boost: 0.3)
        add(.second, rot: a.s, local: around(a.s, 33), boost: 0.4)
        add(.cap, rot: 0, local: CGPoint(x: 0, y: -1), boost: 0.15)
        _ = p
        particles = parts; phase = .exploding(t: 0)
    }

    func draw(_ ctx: CGContext, date: Date) {
        LUME_ACTIVE = lumeActive; defer { LUME_ACTIVE = false }
        ctx.setFillColor(CGColor(gray: 0, alpha: 1)); ctx.fill(CGRect(origin: .zero, size: size))
        switch phase {
        case .moving: drawClock(ctx, center: pos, k: k, pal: PALETTES[pal], date: date)
        case .appearing(let t):
            let f = CGFloat(t / Self.appearDur), e = 1 - pow(1 - f, 3)
            drawClock(ctx, center: pos, k: k, pal: PALETTES[pal], date: date, alpha: e, scale: 0.6 + 0.4*e)
        case .exploding(let t):
            let fade = CGFloat(max(0, 1 - t / Self.explodeDur))
            for q in particles {
                ctx.saveGState(); ctx.setAlpha(fade)
                ctx.translateBy(x: q.pos.x, y: q.pos.y); ctx.scaleBy(x: k, y: -k); ctx.rotate(by: q.ang * .pi/180)
                let st = style(PALETTES[q.pal]); switch q.prim { case .hand, .second, .cap: withShadow(ctx, k, st) { drawPrim(ctx, q.prim, st) }; default: drawPrim(ctx, q.prim, st) }; ctx.restoreGState()
            }
        }
        if brightness < 1 { ctx.setFillColor(CGColor(gray: 0, alpha: 1 - brightness)); ctx.fill(CGRect(origin: .zero, size: size)) }
    }
}
