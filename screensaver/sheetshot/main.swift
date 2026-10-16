import AppKit
_ = NSApplication.shared
var b: [String: NSButton] = [:], p: [String: NSPopUpButton] = [:]
let w = BauhausClockView.makeSheet(target: nil, boxes: &b, pops: &p)
Prefs.register()
for (k, x) in b { x.state = (Prefs.defaults?.bool(forKey: k) ?? true) ? .on : .off }
p["dial"]?.selectItem(withTitle: "Pilot"); p["movement"]?.selectItem(withTitle: "Digital"); p["size"]?.selectItem(at: 0)
let v = w.contentView!; v.appearance = NSAppearance(named: .aqua)
let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!; v.cacheDisplay(in: v.bounds, to: rep)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("sheet ok")
