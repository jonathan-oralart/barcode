#!/bin/bash
set -e

if [ $# -lt 2 ]; then
    echo "Usage: ./update_appcast.sh VERSION FILE_SIZE"
    echo ""
    echo "Example: ./update_appcast.sh 1.1 2534567"
    echo ""
    echo "This will automatically update appcast.xml on gh-pages branch"
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

# Create new item XML
NEW_ITEM="    <item>
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
            url=\"${DOWNLOAD_URL}\" 
            sparkle:version=\"${VERSION}\" 
            sparkle:shortVersionString=\"${VERSION}\"
            length=\"${FILE_SIZE}\" 
            type=\"application/octet-stream\" />
        <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
    </item>"

# Save current branch
CURRENT_BRANCH=$(git branch --show-current)

# Switch to gh-pages and update
echo "🔄 Switching to gh-pages branch..."
git checkout gh-pages
git pull

# Check if appcast.xml exists
if [ ! -f "appcast.xml" ]; then
    echo "❌ appcast.xml not found on gh-pages branch"
    echo "   Please create it first - see GITHUB_UPDATES_GUIDE.md"
    git checkout "$CURRENT_BRANCH"
    exit 1
fi

# Insert new item after <language>en</language> line
echo "✏️  Adding new release to appcast.xml..."
awk -v new="$NEW_ITEM" '
    /<language>en<\/language>/ {
        print
        print ""
        print new
        print ""
        next
    }
    {print}
' appcast.xml > appcast.xml.tmp
mv appcast.xml.tmp appcast.xml

# Commit and push
git add appcast.xml
git commit -m "Release v${VERSION}"
git push

# Switch back to original branch
git checkout "$CURRENT_BRANCH"

OWNER=$(gh repo view --json owner -q '.owner.login')
REPO=$(gh repo view --json name -q '.name')

echo ""
echo "✅ Appcast updated successfully!"
echo "🌐 Live at: https://${OWNER}.github.io/${REPO}/appcast.xml"
echo ""
echo "Users will see the update within 24 hours (or when they click 'Check for Updates')"


