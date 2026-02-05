#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="AutoCopy"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        📦 Building AutoCopy.app v2               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ---- Preflight ----

if [[ "$(uname)" != "Darwin" ]]; then echo "❌ macOS only."; exit 1; fi
if ! command -v swiftc &>/dev/null; then echo "❌ Run: xcode-select --install"; exit 1; fi

for f in main.swift AppDelegate.swift Info.plist; do
    if [[ ! -f "$SCRIPT_DIR/$f" ]]; then
        echo "❌ Missing: $SCRIPT_DIR/$f"
        echo ""; echo "Folder contents:"; ls -1 "$SCRIPT_DIR"; exit 1
    fi
done
echo "✅ Source files found"

# ---- Build ----

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🔨 Compiling..."
swiftc -O -whole-module-optimization \
    -o "$BUILD_DIR/$APP_NAME" \
    "$SCRIPT_DIR/main.swift" \
    "$SCRIPT_DIR/AppDelegate.swift" \
    -framework Cocoa \
    -framework Carbon \
    -framework ServiceManagement \
    -target "$(uname -m)-apple-macosx12.0"
echo "✅ Compiled"

# ---- Bundle ----

echo "📁 Creating .app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# ---- Icon ----

echo "🎨 Generating icon..."
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

cat > "$BUILD_DIR/_icon.swift" << 'EOF'
import Cocoa
func draw(size px: Int, to path: String) {
    let s = CGFloat(px)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    guard let c = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); return }
    // Blue rounded background
    let bg = CGRect(x: s*0.05, y: s*0.05, width: s*0.9, height: s*0.9)
    c.setFillColor(CGColor(red: 0.18, green: 0.47, blue: 0.95, alpha: 1))
    c.addPath(CGPath(roundedRect: bg, cornerWidth: s*0.2, cornerHeight: s*0.2, transform: nil))
    c.fillPath()
    // White clipboard
    let bw=s*0.5, bh=s*0.56, bx=(s-bw)/2, by=s*0.14
    c.setFillColor(CGColor(red:1,green:1,blue:1,alpha:1))
    c.addPath(CGPath(roundedRect: CGRect(x:bx,y:by,width:bw,height:bh), cornerWidth:s*0.04, cornerHeight:s*0.04, transform:nil))
    c.fillPath()
    // Clip top
    let tw=s*0.22, th=s*0.11, tx=(s-tw)/2, ty=by+bh-s*0.03
    c.addPath(CGPath(roundedRect: CGRect(x:tx,y:ty,width:tw,height:th), cornerWidth:s*0.03, cornerHeight:s*0.03, transform:nil))
    c.fillPath()
    // Text lines
    c.setFillColor(CGColor(red:0.18,green:0.47,blue:0.95,alpha:0.3))
    for (i,w) in [0.36,0.28,0.34,0.22].enumerated() {
        c.fill(CGRect(x:bx+s*0.07, y:by+s*0.07+CGFloat(i)*s*0.09, width:s*CGFloat(w), height:s*0.035))
    }
    // Green check
    c.setStrokeColor(CGColor(red:0.15,green:0.75,blue:0.35,alpha:1))
    c.setLineWidth(s*0.05); c.setLineCap(.round); c.setLineJoin(.round)
    let cx=s*0.55, cy=s*0.19
    c.move(to: CGPoint(x:cx, y:cy+s*0.07))
    c.addLine(to: CGPoint(x:cx+s*0.06, y:cy))
    c.addLine(to: CGPoint(x:cx+s*0.18, y:cy+s*0.16))
    c.strokePath()
    img.unlockFocus()
    guard let t=img.tiffRepresentation, let r=NSBitmapImageRep(data:t),
          let p=r.representation(using:.png, properties:[:]) else { return }
    try? p.write(to: URL(fileURLWithPath: path))
}
let d=CommandLine.arguments[1]
for (sz,nm) in [(16,"icon_16x16.png"),(32,"icon_16x16@2x.png"),(32,"icon_32x32.png"),
    (64,"icon_32x32@2x.png"),(128,"icon_128x128.png"),(256,"icon_128x128@2x.png"),
    (256,"icon_256x256.png"),(512,"icon_256x256@2x.png"),(512,"icon_512x512.png"),
    (1024,"icon_512x512@2x.png")] { draw(size:sz, to:"\(d)/\(nm)") }
EOF

if swiftc -o "$BUILD_DIR/_icon" "$BUILD_DIR/_icon.swift" -framework Cocoa 2>/dev/null \
    && "$BUILD_DIR/_icon" "$ICONSET" 2>/dev/null \
    && iconutil -c icns -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" "$ICONSET" 2>/dev/null; then
    echo "✅ Icon created"
else
    echo "⚠️  Icon skipped (non-critical)"
fi

# ---- Install ----

rm -rf "/Applications/$APP_NAME.app" 2>/dev/null
cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"
echo "✅ Installed → /Applications/$APP_NAME.app"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🚀 SETUP:"
echo ""
echo "  1. Grant Accessibility access (one-time):"
echo "     System Settings → Privacy & Security → Accessibility"
echo "     → Click '+' → /Applications → AutoCopy → Toggle ON"
echo ""
echo "  2. Launch:"
echo "     open /Applications/AutoCopy.app"
echo ""
echo "  📋 icon appears in menu bar — select any text to auto-copy!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
