import AppKit
// Simulates System Settings: host window presents configureSheet as a sheet, OK/Cancel end it, repeat.
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
let host = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 700, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
host.isReleasedWhenClosed = false; host.orderFront(nil)
let view = BauhausClockView(frame: NSRect(x: 0, y: 0, width: 280, height: 175), isPreview: true)!
var ok = 0, prev: NSWindow? = nil
weak var weakOld: NSWindow? = nil
for i in 0..<6 {
    guard let s = view.configureSheet else { print("FAIL no sheet \(i)"); exit(1) }
    if s === prev { print("FAIL reused window \(i)"); exit(1) }
    host.beginSheet(s) { _ in }
    RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    let attached = host.attachedSheet === s
    let sel = i % 2 == 0 ? "closeSheet:" : "cancelSheet:"
    view.perform(Selector(sel), with: nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    let detached = host.attachedSheet == nil && !s.isVisible && !view.hasOpenSheet
    print("cycle \(i) \(sel) presented=\(attached) ended=\(detached)")
    if attached && detached { ok += 1 }
    if i == 0 { weakOld = s }
    prev = s
}
autoreleasepool {}
print(ok == 6 ? "SHEET CYCLE PASS (6/6), old sheet released=\(weakOld == nil)" : "SHEET CYCLE FAIL \(ok)/6")
exit(ok == 6 ? 0 : 1)
