#!/bin/bash
# Builds FinglishIME.app; with "install" copies it to ~/Library/Input Methods
set -e
cd "$(dirname "$0")"
APP=build/FinglishIME.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -swift-version 5 -O Sources/*.swift -o "$APP/Contents/MacOS/FinglishIME" -framework Cocoa -framework InputMethodKit -framework Carbon
swiftc make_icon.swift -o build/make_icon && build/make_icon "$APP/Contents/Resources/icon.tiff"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
 <key>CFBundleExecutable</key><string>FinglishIME</string>
 <key>CFBundleIdentifier</key><string>org.finglishime.inputmethod.Finglish</string>
 <key>CFBundleName</key><string>Finglish</string>
 <key>CFBundleDisplayName</key><string>Finglish</string>
 <key>CFBundleDevelopmentRegion</key><string>en</string>
 <key>CFBundlePackageType</key><string>APPL</string>
 <key>CFBundleShortVersionString</key><string>1.0</string>
 <key>CFBundleVersion</key><string>1</string>
 <key>LSMinimumSystemVersion</key><string>12.0</string>
 <key>LSUIElement</key><true/>
 <key>NSPrincipalClass</key><string>NSApplication</string>
 <key>InputMethodConnectionName</key><string>FinglishIME_Connection</string>
 <key>InputMethodServerControllerClass</key><string>FinglishInputController</string>
 <key>tsInputMethodIconFileKey</key><string>icon.tiff</string>
 <key>tsInputMethodCharacterRepertoireKey</key><array><string>Arab</string></array>
 <key>ComponentInputModeDict</key><dict>
  <key>tsInputModeListKey</key><dict>
   <key>org.finglishime.inputmethod.Finglish.Persian</key><dict>
    <key>TISIntendedLanguage</key><string>fa</string>
    <key>TISInputSourceID</key><string>org.finglishime.inputmethod.Finglish.Persian</string>
    <key>tsInputModeScriptKey</key><string>smArabic</string>
    <key>tsInputModeMenuIconFileKey</key><string>icon.tiff</string>
    <key>tsInputModePaletteIconFileKey</key><string>icon.tiff</string>
    <key>TISIconIsTemplate</key><true/>
    <key>tsInputModeIsVisibleKey</key><true/>
    <key>tsInputModePrimaryInputModeKey</key><true/>
    <key>tsInputModeDefaultStateKey</key><true/>
    <key>tsInputModeKeyEquivalentModifiersKey</key><integer>0</integer>
   </dict>
  </dict>
  <key>tsVisibleInputModeOrderedArrayKey</key><array><string>org.finglishime.inputmethod.Finglish.Persian</string></array>
 </dict>
</dict></plist>
PLIST
# Display name of the input mode in System Settings / the input menu
mkdir -p "$APP/Contents/Resources/en.lproj"
cat > "$APP/Contents/Resources/en.lproj/InfoPlist.strings" <<'STR'
"org.finglishime.inputmethod.Finglish.Persian" = "Finglish";
CFBundleName = "Finglish";
CFBundleDisplayName = "Finglish";
STR
codesign --force --deep -s - "$APP"
if [ "$1" = "install" ]; then
  mkdir -p "$HOME/Library/Input Methods"
  pkill -x FinglishIME 2>/dev/null || true
  rm -rf "$HOME/Library/Input Methods/FinglishIME.app"
  cp -R "$APP" "$HOME/Library/Input Methods/"
  echo "Installato in ~/Library/Input Methods"
fi
