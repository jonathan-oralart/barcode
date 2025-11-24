# Sparkle Auto-Update Setup Guide

Your app now has automatic update support via Sparkle! Here's how to configure and use it.

## What's Been Done

✅ Sparkle framework added to the project  
✅ Network access enabled in sandbox  
✅ "Check for Updates" menu item added  
✅ Auto-update checking on launch configured

## Quick Start

### 1. Update the Feed URL

The app is configured to check for updates at:
```
https://yourdomain.com/appcast.xml
```

**Change this URL** in Xcode:
1. Open your project in Xcode
2. Select the **barcode** target
3. Go to **Build Settings**
4. Search for "SUFeedURL"
5. Replace `https://yourdomain.com/appcast.xml` with your actual URL

**Recommended hosting options:**
- **GitHub Pages** (free, easy) - `https://yourusername.github.io/barcode/appcast.xml`
- **AWS S3** - `https://your-bucket.s3.amazonaws.com/appcast.xml`
- **Your own server** - Any HTTPS URL

### 2. Build and Archive Your App

```bash
# Build for distribution
xcodebuild archive \
  -scheme barcode \
  -archivePath ./build/barcode.xcarchive \
  -configuration Release

# Export the app
xcodebuild -exportArchive \
  -archivePattern ./build/barcode.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist exportOptions.plist
```

Or use Xcode: **Product** → **Archive** → **Distribute App** → **Copy App**

### 3. Create Your Appcast File

Save this as `appcast.xml` and host it at your feed URL:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Barcode Scanner Updates</title>
        <link>https://yourdomain.com/appcast.xml</link>
        <description>Updates for USB Barcode Scanner</description>
        <language>en</language>
        <item>
            <title>Version 1.1</title>
            <description><![CDATA[
                <h2>What's New</h2>
                <ul>
                    <li>Added automatic update support</li>
                    <li>Improved barcode scanning reliability</li>
                    <li>Bug fixes and performance improvements</li>
                </ul>
            ]]></description>
            <pubDate>Mon, 24 Nov 2025 12:00:00 +0000</pubDate>
            <enclosure 
                url="https://yourdomain.com/downloads/barcode-1.1.zip" 
                sparkle:version="1.1" 
                sparkle:shortVersionString="1.1"
                length="2534567" 
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
```

### 4. Prepare Your Update Package

```bash
# Create a zip of your app
cd /path/to/barcode.app/parent/directory
zip -r barcode-1.1.zip barcode.app

# Get the file size (needed for appcast)
ls -l barcode-1.1.zip
```

### 5. Upload Files

Upload to your hosting:
```
https://yourdomain.com/appcast.xml          # Your appcast file
https://yourdomain.com/downloads/barcode-1.1.zip  # Your zipped app
```

## Testing Updates

### Test Before Releasing

```bash
# Run your app with debug logging
defaults write jonathan-oralart.barcode SUEnableAutomaticChecks -bool YES
defaults write jonathan-oralart.barcode SUScheduledCheckInterval -int 3600

# Check Sparkle logs in Console.app
# Search for "Sparkle" or "SUUpdater"
```

### Simulate an Update

1. Build version 1.0 of your app
2. Install and run it
3. Create an appcast with version 1.1
4. Build version 1.1 (increment `MARKETING_VERSION` in Xcode)
5. Click "Check for Updates" in the menu bar

## Configuration Options

### Update Check Frequency

By default, Sparkle checks for updates automatically on launch (not more than once per day).

To customize, add to your AppDelegate init:

```swift
// In AppDelegate.swift, modify the init method:
override init() {
    let configuration = SPUUpdaterConfiguration()
    // Check every 2 hours
    configuration.scheduledCheckInterval = 7200
    
    updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    super.init()
}
```

### Disable Automatic Checks

If you only want manual updates:

```swift
updaterController = SPUStandardUpdaterController(
    startingUpdater: false,  // Change to false
    updaterDelegate: nil,
    userDriverDelegate: nil
)
```

## Advanced: Code Signing Updates

For production apps, you should sign your updates for security.

### 1. Generate EdDSA Keys

```bash
# Install generate_keys tool
brew install sparkle

# Generate keys
generate_keys

# This creates:
# - sparkle_eddsa_private.key (KEEP SECRET!)
# - sparkle_eddsa_public.key (embed in app)
```

### 2. Add Public Key to Your App

In Xcode Build Settings, add:
```
SUPublicEDKey = YOUR_PUBLIC_KEY_HERE
```

### 3. Sign Your Update

```bash
sign_update barcode-1.1.zip
# Outputs signature for appcast
```

### 4. Add Signature to Appcast

```xml
<enclosure 
    url="https://yourdomain.com/downloads/barcode-1.1.zip" 
    sparkle:version="1.1"
    sparkle:edSignature="SIGNATURE_HERE"
    length="2534567" 
    type="application/octet-stream" />
```

## Using GitHub Releases (Easiest Option)

### 1. Setup GitHub Pages

```bash
# Create a gh-pages branch
git checkout --orphan gh-pages
git rm -rf .
echo "# Barcode Scanner Updates" > README.md
git add README.md
git commit -m "Initial gh-pages"
git push origin gh-pages
git checkout main
```

### 2. Update Feed URL

Change in Xcode Build Settings:
```
SUFeedURL = https://YOUR_USERNAME.github.io/barcode/appcast.xml
```

### 3. Create Release Script

Save as `release.sh`:

```bash
#!/bin/bash
VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh 1.1"
    exit 1
fi

# Build app
xcodebuild -scheme barcode -configuration Release -archivePath ./build/barcode.xcarchive archive
xcodebuild -exportArchive -archivePattern ./build/barcode.xcarchive -exportPath ./build -exportOptionsPlist exportOptions.plist

# Create zip
cd build
zip -r "barcode-${VERSION}.zip" barcode.app

# Create GitHub release
gh release create "v${VERSION}" "barcode-${VERSION}.zip" --title "Version ${VERSION}" --notes "Release notes here"

# Update appcast (you'll need to manually update the appcast.xml in gh-pages branch)
```

## Troubleshooting

### Updates Not Appearing

1. **Check Console logs**: Open Console.app and filter for "Sparkle"
2. **Verify feed URL**: Make sure it's HTTPS and accessible
3. **Check version numbers**: New version must be > current version
4. **Clear cache**: `defaults delete jonathan-oralart.barcode`

### Network Issues

Make sure **Outgoing Network Connections** is enabled in:
- Xcode → Target → Signing & Capabilities → App Sandbox → Network

### App Won't Update

1. Verify the zip contains the `.app` file correctly
2. Check file permissions: `chmod -R 755 barcode.app`
3. Ensure bundle identifier matches

## Version Numbering

Sparkle compares versions semantically:
- `1.0` < `1.1` < `2.0`
- `1.0.1` < `1.0.2`
- `1.0-beta` < `1.0`

Update version in Xcode:
1. Select target
2. **General** tab
3. **Version** field (this is `MARKETING_VERSION`)

## Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Appcast Specification](https://sparkle-project.org/documentation/publishing/)
- [Code Signing Guide](https://sparkle-project.org/documentation/code-signing/)

## Need Help?

Common issues:
- **403/404 on feed**: Check URL and hosting permissions
- **Update downloads but won't install**: Check zip structure
- **Silent failures**: Enable logging in Console.app

---

**Your app is ready!** The update system is active. Users will be notified when updates are available.


