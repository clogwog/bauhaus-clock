import AppKit
_ = NSApplication.shared
var b: [String: NSButton] = [:], p: [String: NSPopUpButton] = [:], fp: FacePicker? = nil
let w = BauhausClockView.makeSheet(target: nil, boxes: &b, pops: &p, picker: &fp)
for (k, x) in b { x.state = (Prefs.DEFAULTS[k] as? Bool ?? false) ? .on : .off }
fp?.selected = "Pilot"; p["movement"]?.selectItem(withTitle: "Digital"); p["size"]?.selectItem(at: 0)
let v = w.contentView!; v.appearance = NSAppearance(named: .aqua)
let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!; v.cacheDisplay(in: v.bounds, to: rep)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("sheet ok")
