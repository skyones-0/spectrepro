#!/usr/bin/env bash
# ==============================================================================
# update-spectrepro.sh
# 
# Syncs your custom SpectrePro fork with upstream, preserves all custom features
# (Quick Commands, Hardware Watcher, Port Detector, Process Monitor),
# compiles the build, and optionally installs to /Applications/SpectrePro.app.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG="ReleaseLocal"
ARCH="arm64"
INSTALL_APP=false

# Parse optional arguments
for arg in "$@"; do
    case $arg in
        --debug)
            CONFIG="Debug"
            shift
            ;;
        --install)
            INSTALL_APP=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./update-spectrepro.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug     Build in Debug mode instead of ReleaseLocal"
            echo "  --install   Automatically replace /Applications/SpectrePro.app"
            echo "  -h, --help  Show this help message"
            exit 0
            ;;
    esac
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 SpectrePro Synchronizer & Builder (macOS ARM64)"
echo "  Configuration: $CONFIG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Check git remotes
if ! git remote get-url upstream >/dev/null 2>&1; then
    echo "Setting up upstream remote (spectrepro-org/spectrepro)..."
    git remote add upstream https://github.com/spectrepro-org/spectrepro.git
fi

# 2. Fetch upstream
echo "📡 Fetching official upstream updates..."
git fetch upstream main

# 3. Merge upstream into current branch
CURRENT_BRANCH="$(git branch --show-current)"
echo "🔀 Merging upstream/main into $CURRENT_BRANCH..."

if git merge upstream/main -m "Merge upstream/main into $CURRENT_BRANCH" 2>/dev/null; then
    echo "✅ Git merge completed without conflicts."
else
    echo "⚠️  Local changes detected. Shelving changes temporarily..."
    git stash push -u -m "Auto-stash before upstream sync $(date +%Y-%m-%d-%H%M%S)"
    if ! git merge upstream/main -m "Merge upstream/main into $CURRENT_BRANCH"; then
        echo ""
        echo "❌ Merge conflict detected."
        echo "   Please resolve conflicts and run 'git commit'."
        echo "   (Previous local changes are preserved in 'git stash list')"
        exit 1
    fi
    echo "📦 Restoring local changes..."
    git stash pop
fi

# 4. Clean extended attributes to prevent code signing issues
echo "🧹 Cleaning extended attributes..."
xattr -cr macos/build 2>/dev/null || true

# 5. Build SpectrePro
echo "🔨 Building SpectrePro ($CONFIG, macOS ARM64)..."
ZIG_OPT="ReleaseFast"
if [ "$CONFIG" = "Debug" ]; then
    ZIG_OPT="Debug"
fi
zig build -Doptimize="$ZIG_OPT" -Demit-macos-app=true

BUILD_APP="macos/build/$CONFIG/SpectrePro.app"
if [ ! -d "$BUILD_APP" ]; then
    echo "❌ Error: Compiled bundle not found at $BUILD_APP"
    exit 1
fi

echo "✅ Build completed successfully: $BUILD_APP"

# 6. Install to /Applications
if [ "$INSTALL_APP" = false ]; then
    read -p "Copy new build to /Applications/SpectrePro.app? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_APP=true
    fi
fi

if [ "$INSTALL_APP" = true ]; then
    echo "📲 Installing to /Applications/SpectrePro.app..."
    pkill -f "SpectrePro.app" 2>/dev/null || true
    sleep 0.5
    if [ -d "/Applications/SpectrePro.app" ]; then
        rm -rf /Applications/SpectrePro.app
    fi
    cp -R "$BUILD_APP" /Applications/SpectrePro.app
    xattr -cr /Applications/SpectrePro.app 2>/dev/null || true
    
    # Sign with developer identity if present to persist TCC permissions
    DEV_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -E "Apple Development:" | head -n 1 | awk -F'"' '{print $2}')
    if [ -n "$DEV_IDENTITY" ]; then
        echo "🔏 Signing with Apple Development certificate ($DEV_IDENTITY)..."
        codesign --force --deep --sign "$DEV_IDENTITY" --entitlements macos/SpectreProReleaseLocal.entitlements /Applications/SpectrePro.app 2>/dev/null || true
    fi
    echo "🎉 SpectrePro successfully installed to /Applications/SpectrePro.app"
    echo "   You can open it from Launchpad, Spotlight, or the Dock."
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ SpectrePro updated with all custom features!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
