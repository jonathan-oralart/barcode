#!/bin/bash
set -e

if [ $# -lt 2 ]; then
    echo "Usage: ./update_appcast.sh VERSION FILE_SIZE"
    echo ""
    echo "Example: ./update_appcast.sh 1.1 2534567"
    echo ""
    echo "This will automatically update appcast.xml on main branch"
    exit 1
fi

VERSION=$1
FILE_SIZE=$2

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    echo "   Install it: brew install gh"
    exit 1
fi

# Get repo info
REPO_NAME=$(gh repo view --json nameWithOwner -q .nameWithOwner)
DOWNLOAD_URL="https://github.com/${REPO_NAME}/releases/download/v${VERSION}/barcode-${VERSION}.zip"

echo "📝 Updating appcast for version ${VERSION}..."

# Check if appcast.xml exists
APPCAST_FILE="appcast.xml"
if [ ! -f "$APPCAST_FILE" ]; then
    echo "❌ appcast.xml not found in repository root"
    echo "   Please create it first - see GITHUB_UPDATES_GUIDE.md"
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
echo "✏️  Adding new release to appcast.xml..."
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

# Commit and push
git add appcast.xml
git commit -m "Release v${VERSION}"
git push

OWNER=$(gh repo view --json owner -q '.owner.login')
REPO=$(gh repo view --json name -q '.name')

echo ""
echo "✅ Appcast updated successfully!"
echo "🌐 Live at: https://${OWNER}.github.io/${REPO}/appcast.xml"
echo ""
echo "Users will see the update within 24 hours (or when they click 'Check for Updates')"


