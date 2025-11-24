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
echo "📝 Now updating appcast.xml..."

# Update appcast.xml
APPCAST_FILE="appcast.xml"

if [ ! -f "$APPCAST_FILE" ]; then
    echo "❌ appcast.xml not found in repository root"
    exit 1
fi

# Create new item XML in a temporary file
cat > "${APPCAST_FILE}.new_item" << EOF
    <item>
        <title>Version ${VERSION}</title>
        <description><![CDATA[
            <h2>What's New in Version ${VERSION}</h2>
            <ul>
                <li>New features and improvements</li>
                <li>Bug fixes and performance enhancements</li>
            </ul>
        ]]></description>
        <pubDate>$(date -u +"%a, %d %b %Y %H:%M:%S %z")</pubDate>
        <enclosure
            url="${DOWNLOAD_URL}"
            sparkle:version="${VERSION}"
            sparkle:shortVersionString="${VERSION}"
            length="${FILE_SIZE}"
            type="application/octet-stream" />
        <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
    </item>
EOF

# Insert new item after <language>en</language> line
awk '
    /<language>en<\/language>/ {
        print
        print ""
        while ((getline line < "'"${APPCAST_FILE}.new_item"'") > 0) {
            print line
        }
        print ""
        next
    }
    {print}
' "$APPCAST_FILE" > "${APPCAST_FILE}.tmp"
mv "${APPCAST_FILE}.tmp" "$APPCAST_FILE"
rm "${APPCAST_FILE}.new_item"

# Commit and push appcast update
git add appcast.xml
git commit -m "Release v${VERSION} - Update appcast"
git push

OWNER=$(echo "$REPO_NAME" | cut -d'/' -f1)
REPO=$(echo "$REPO_NAME" | cut -d'/' -f2)

echo ""
echo "✅ Appcast updated and pushed!"
echo "🌐 Live at: https://${OWNER}.github.io/${REPO}/appcast.xml"
echo ""
echo "Done! 🎉"
echo "Users will see the update within 24 hours (or when they click 'Check for Updates')"


