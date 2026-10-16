#!/bin/bash
# Run on the Mac from this folder: tests, thumbnails, universal build, install.
set -e
xcrun swiftc -O Clock.swift Faces.swift Sim.swift main.swift -o harness && ./harness
B=BauhausClock.saver/Contents; rm -rf BauhausClock.saver; mkdir -p $B/MacOS $B/Resources
cp Info.plist $B/ && cp thumbnail.png thumbnail@2x.png $B/Resources/
for a in arm64 x86_64; do xcrun swiftc -O -target $a-apple-macos13 -emit-library -module-name BauhausClock -framework ScreenSaver Clock.swift Faces.swift Sim.swift View.swift -o $a.dylib; done
lipo -create arm64.dylib x86_64.dylib -output $B/MacOS/BauhausClock && lipo -info $B/MacOS/BauhausClock
codesign --force -s - BauhausClock.saver && codesign -v BauhausClock.saver && echo BUILD_OK
rm -rf ~/Library/Screen\ Savers/BauhausClock.saver && cp -R BauhausClock.saver ~/Library/Screen\ Savers/
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' ~/Library/Screen\ Savers/BauhausClock.saver/Contents/Info.plist
killall legacyScreenSaver 2>/dev/null && echo killed || echo "no legacyScreenSaver running"
