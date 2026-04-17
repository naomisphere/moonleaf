#!/bin/bash

SERVER_URL="${3:-https://github.com/naomisphere/moonleaf}"
REPO=$(echo "$SERVER_URL" | sed 's|https://github.com/||')
RAW_URL="https://raw.githubusercontent.com/$REPO/main/latest"

LATEST=$(curl -s "$RAW_URL")
CURRENT="$1"

if [ "$LATEST" != "$CURRENT" ]; then
    C_TMPDIR="$2/.tmp"
    mkdir -p "$C_TMPDIR"

    LATEST_URL="$SERVER_URL/releases/download/$LATEST/moonleaf.dmg"
    DMG_PATH="$C_TMPDIR/moonleaf.dmg"

    curl -L -o "$DMG_PATH" "$LATEST_URL"

    VOLUME_NAME="moonleaf"

    if [ -d "/Volumes/$VOLUME_NAME" ]; then
        hdiutil detach "/Volumes/$VOLUME_NAME" -force
    fi

    hdiutil attach "$DMG_PATH"
    cp -rf "/Volumes/$VOLUME_NAME/moonleaf.app" "/Applications/"

    if [ -d "/Applications/macpaper.app" ]; then
        rm -rf "/Applications/macpaper.app"
    fi
    
    hdiutil detach "/Volumes/$VOLUME_NAME"

    rm -rf "$C_TMPDIR"

    echo "update completed"
else
    echo "app is up to date"
fi

exit 0