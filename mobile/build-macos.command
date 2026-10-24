#!/bin/bash
# Builds the PWP POS Mac app and installs it into /Applications.
# Double-click in Finder, or run: ./build-macos.command
# First time only: chmod +x build-macos.command
#
# Uses the production backend built into the app. To point at another
# backend: API_BASE_URL=http://192.168.1.42:5000/api ./build-macos.command

cd "$(dirname "$0")" || exit 1

finish() {
  echo
  read -r -p "Press Enter to close..." _
  exit "$1"
}

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed. Follow https://docs.flutter.dev/get-started/install/macos and run this again."
  finish 1
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode is not installed or not set up. Install Xcode from the App Store, open it once, then run:"
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  echo "  sudo xcodebuild -runFirstLaunch"
  finish 1
fi

flutter config --enable-macos-desktop >/dev/null
flutter pub get || finish 1

DEFINES=()
if [ -n "$API_BASE_URL" ]; then
  echo "Using backend: $API_BASE_URL"
  DEFINES+=("--dart-define=API_BASE_URL=$API_BASE_URL")
fi

flutter build macos --release "${DEFINES[@]}" || finish 1

APP="build/macos/Build/Products/Release/PWP POS.app"
if [ ! -d "$APP" ]; then
  echo "Build finished but $APP was not found."
  finish 1
fi

mkdir -p dist
rm -f "dist/PWP-POS-mac.zip"
ditto -c -k --keepParent "$APP" "dist/PWP-POS-mac.zip"
echo "Shareable copy: $(pwd)/dist/PWP-POS-mac.zip"

read -r -p "Install into /Applications now? (Y/n) " answer
case "$answer" in
  n|N|no|NO) open "$(dirname "$APP")" ;;
  *)
    rm -rf "/Applications/PWP POS.app"
    cp -R "$APP" /Applications/ || finish 1
    echo "Installed. Opening PWP POS..."
    open "/Applications/PWP POS.app"
    ;;
esac

finish 0
