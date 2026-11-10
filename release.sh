#!/bin/bash
set -e

# Get current version from project file
CURRENT_VERSION=$(grep -m 1 "MARKETING_VERSION = " barcode.xcodeproj/project.pbxproj | sed 's/.*MARKETING_VERSION = \([^;]*\);/\1/')

if [ -z "$CURRENT_VERSION" ]; then
    echo "❌ Could not read current version from project file"
    exit 1
fi

# If version is provided, use it; otherwise auto-increment
if [ -n "$1" ]; then
    VERSION=$1
    echo "📌 Using specified version: $VERSION"
else
    # Auto-increment: split version and increment last number
    if [[ $CURRENT_VERSION =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        NEW_MINOR=$((MINOR + 1))
        VERSION="${MAJOR}.${NEW_MINOR}"
    elif [[ $CURRENT_VERSION =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        PATCH="${BASH_REMATCH[3]}"
        NEW_PATCH=$((PATCH + 1))
        VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
    else
        echo "❌ Could not parse version format: $CURRENT_VERSION"
        echo "   Please specify version manually: ./release.sh 1.1"
        exit 1
    fi
    echo "📈 Auto-incrementing version: $CURRENT_VERSION → $VERSION"
fi

echo "🔨 Building barcode version $VERSION..."
echo ""

# Update app version in project file
echo "   → Updating app version to $VERSION..."
sed -i.bak "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/" barcode.xcodeproj/project.pbxproj
rm barcode.xcodeproj/project.pbxproj.bak

# Create build directory
mkdir -p build

# Build the app
echo "   → Archiving app..."
if ! xcodebuild -scheme barcode \
  -configuration Release \
  -archivePath ./build/barcode.xcarchive \
  archive > build/archive.log 2>&1; then
    echo "❌ Archive failed. Check build/archive.log for details."
    tail -20 build/archive.log
    exit 1
fi

# Export app
echo "   → Exporting app..."
if ! xcodebuild -exportArchive \
  -archivePath ./build/barcode.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist exportOptions.plist > build/export.log 2>&1; then
    echo "❌ Export failed. Check build/export.log for details."
    tail -20 build/export.log
    exit 1
fi

# Verify app exists
if [ ! -d "./build/barcode.app" ]; then
    echo "❌ Build failed - barcode.app not found"
    exit 1
fi

echo ""
echo "✅ Build complete"
echo ""

# Create zip
cd build
echo "📦 Creating zip..."
echo "   → Compressing barcode.app..."
zip -r -q "barcode-${VERSION}.zip" barcode.app
FILE_SIZE=$(stat -f%z "barcode-${VERSION}.zip" 2>/dev/null || stat -c%s "barcode-${VERSION}.zip")
cd ..

echo "✅ Created barcode-${VERSION}.zip (${FILE_SIZE} bytes)"
echo ""

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
echo "   → Uploading to GitHub..."
if ! gh release create "v${VERSION}" \
  "./build/barcode-${VERSION}.zip" \
  --title "Version ${VERSION}" \
  --notes "Release ${VERSION} - USB Barcode Scanner

## Installation
Download barcode-${VERSION}.zip, unzip it, and move barcode.app to your Applications folder.

## Auto-Update
Existing users will be notified of this update automatically." > /dev/null 2>&1; then
    echo "❌ GitHub release creation failed"
    exit 1
fi

# Get download URL
REPO_NAME=$(gh repo view --json nameWithOwner -q .nameWithOwner)
DOWNLOAD_URL="https://github.com/${REPO_NAME}/releases/download/v${VERSION}/barcode-${VERSION}.zip"

echo "✅ GitHub release created!"
echo "   🌐 https://github.com/${REPO_NAME}/releases/tag/v${VERSION}"
echo ""
echo "📝 Updating appcast.xml..."

# Update appcast.xml
echo "   → Generating appcast entry..."
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
echo "   → Committing changes..."
git add appcast.xml barcode.xcodeproj/project.pbxproj > /dev/null 2>&1
git commit -m "Release v${VERSION} - Update appcast and version" > /dev/null 2>&1
echo "   → Pushing to GitHub..."
git push > /dev/null 2>&1

OWNER=$(echo "$REPO_NAME" | cut -d'/' -f1)
REPO=$(echo "$REPO_NAME" | cut -d'/' -f2)

echo "✅ Appcast updated and pushed!"
echo "   🌐 https://$(cat CNAME)/appcast.xml"
echo ""
echo "🎉 Done!"
echo ""
echo "Users will see the update within 24 hours (or when they click 'Check for Updates')"


