#!/bin/bash

set -euxo pipefail

ARCHIVE_DIR="../Archive"
DMG_OUTPUT_DIR="../Releases"

# find latest versioned folder in Archive
latest_dir=$(find "$ARCHIVE_DIR" -maxdepth 1 -type d -name 'Porter-*' | sort -V | tail -n 1)

if [[ ! -d "$latest_dir/Porter.app" ]]; then
  echo "no Porter.app found in latest versioned folder."
  exit 1
fi

# extract version number from folder name
version=$(basename "$latest_dir" | sed -E 's/^Porter-([0-9]+\.[0-9]+\.[0-9]+)$/\1/')

if [[ -z "$version" ]]; then
  echo "failed to extract version from $latest_dir"
  exit 1
fi

create-dmg \
  --volname "Porter Installer" \
  --volicon "AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 500 250 \
  --icon-size 100 \
  --icon "Porter.app" 120 100 \
  --hide-extension "Porter.app" \
  --app-drop-link 380 100 \
  "$DMG_OUTPUT_DIR/Porter-$version.dmg" \
  "$latest_dir"

echo "Created Porter-$version.dmg"
