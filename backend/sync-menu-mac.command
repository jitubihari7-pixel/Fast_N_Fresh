#!/bin/bash
# Mac launcher for the menu sync (src/utils/syncMenu2026.js).
# Double-click in Finder, or run: ./sync-menu-mac.command
# First time only: chmod +x sync-menu-mac.command

cd "$(dirname "$0")" || exit 1

finish() {
  echo
  read -r -p "Press Enter to close..." _
  exit "$1"
}

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is not installed. Install the LTS version from https://nodejs.org and run this again."
  finish 1
fi
echo "Node $(node -v)"

if [ ! -d node_modules ]; then
  echo "Installing backend dependencies (first run only)..."
  npm install --omit=dev || finish 1
fi

# Use MONGODB_URI from .env when present; otherwise ask for it for this run
# only (it is not saved to disk).
if [ -z "$MONGODB_URI" ] && ! grep -q '^MONGODB_URI=..*' .env 2>/dev/null; then
  echo "No MONGODB_URI found in backend/.env."
  read -r -s -p "Paste your MongoDB connection string (input hidden): " MONGODB_URI
  echo
  if [ -z "$MONGODB_URI" ]; then
    echo "No connection string given. Nothing was changed."
    finish 1
  fi
  export MONGODB_URI
fi

echo
echo "This updates the LIVE menu (prices, names, categories) to the new 2026 menu."
read -r -p "Continue? (y/N) " answer
case "$answer" in
  y|Y|yes|YES) ;;
  *) echo "Cancelled. Nothing was changed."; finish 0 ;;
esac

node src/utils/syncMenu2026.js
finish $?
