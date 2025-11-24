#!/bin/bash
set -e

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "❌ Usage: ./release.sh 1.1"
    echo ""
    echo "This script will:"
    echo "  1. Build your app for release"
    echo "  2. Create a zip file"
    echo "  3. Create a GitHub release"
    echo "  4. Output appcast XML for you to copy"
    exit 1
fi

echo "🔨 Building barcode version $VERSION..."

# Create build directory
mkdir -p build

# Build the app
xcodebuild -scheme barcode \
  -configuration Release \
  -archivePath ./build/barcode.xcarchive \
  archive

# Export app
xcodebuild -exportArchive \
  -archivePath ./build/barcode.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist exportOptions.plist

# Verify app exists
if [ ! -d "./build/barcode.app" ]; then
    echo "❌ Build failed - barcode.app not found"
    exit 1
fi

echo "✅ Build complete"

# Create zip
cd build
echo "📦 Creating zip..."
zip -r -q "barcode-${VERSION}.zip" barcode.app
FILE_SIZE=$(stat -f%z "barcode-${VERSION}.zip" 2>/dev/null || stat -c%s "barcode-${VERSION}.zip")
cd ..

echo "✅ Created barcode-${VERSION}.zip (${FILE_SIZE} bytes)"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "⚠️  GitHub CLI (gh) not found"
    echo "   Install it: brew install gh"
    echo "   Or manually upload build/barcode-${VERSION}.zip to GitHub Releases"
    echo ""
    echo "📝 Add this to your appcast.xml:"
    echo ""
    echo "<item>"
    echo "    <title>Version ${VERSION}</title>"
    echo "    <description><![CDATA[<ul><li>Update description here</li></ul>]]></description>"
    echo "    <pubDate>$(date -u +"%a, %d %b %Y %H:%M:%S %z")</pubDate>"
    echo "    <enclosure"
    echo "        url=\"https://github.com/YOUR_USERNAME/barcode/releases/download/v${VERSION}/barcode-${VERSION}.zip\""
    echo "        sparkle:version=\"${VERSION}\""
    echo "        sparkle:shortVersionString=\"${VERSION}\""
    echo "        length=\"${FILE_SIZE}\""
    echo "        type=\"application/octet-stream\" />"
    echo "</item>"
    exit 0
fi

# Create GitHub release
echo "🚀 Creating GitHub release v${VERSION}..."
gh release create "v${VERSION}" \
  "./build/barcode-${VERSION}.zip" \
  --title "Version ${VERSION}" \
  --notes "Release ${VERSION} - USB Barcode Scanner

## Installation
Download barcode-${VERSION}.zip, unzip it, and move barcode.app to your Applications folder.

## Auto-Update
Existing users will be notified of this update automatically."

# Get download URL
REPO_NAME=$(gh repo view --json nameWithOwner -q .nameWithOwner)
DOWNLOAD_URL="https://github.com/${REPO_NAME}/releases/download/v${VERSION}/barcode-${VERSION}.zip"

echo ""
echo "✅ GitHub release created!"
echo "🌐 View at: https://github.com/${REPO_NAME}/releases/tag/v${VERSION}"
echo ""
echo "📝 Next: Update appcast.xml on gh-pages branch"
echo ""
echo "Copy this <item> block and add it to the TOP of your appcast.xml:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "    <item>"
echo "        <title>Version ${VERSION}</title>"
echo "        <description><![CDATA["
echo "            <h2>What's New in Version ${VERSION}</h2>"
echo "            <ul>"
echo "                <li>New features and improvements</li>"
echo "                <li>Bug fixes</li>"
echo "            </ul>"
echo "        ]]></description>"
echo "        <pubDate>$(date -u +"%a, %d %b %Y %H:%M:%S %z")</pubDate>"
echo "        <enclosure"
echo "            url=\"${DOWNLOAD_URL}\""
echo "            sparkle:version=\"${VERSION}\""
echo "            sparkle:shortVersionString=\"${VERSION}\""
echo "            length=\"${FILE_SIZE}\""
echo "            type=\"application/octet-stream\" />"
echo "        <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>"
echo "    </item>"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Then run:"
echo "  git checkout gh-pages"
echo "  # Edit appcast.xml - add the item above after <language>en</language>"
echo "  git add appcast.xml"
echo "  git commit -m 'Release v${VERSION}'"
echo "  git push"
echo "  git checkout main"
echo ""
echo "Done! 🎉"


