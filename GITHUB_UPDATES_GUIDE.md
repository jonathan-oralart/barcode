# Auto-Update from GitHub - Quick Setup

Your app can automatically update from GitHub Releases! Here's the simple setup.

## Setup (One-Time, 5 Minutes)

### 1. Enable GitHub Pages

```bash
# Create and push gh-pages branch
git checkout --orphan gh-pages
git rm -rf .
touch .nojekyll
git add .nojekyll
git commit -m "Enable GitHub Pages"
git push origin gh-pages
git checkout main
```

Then on GitHub:
1. Go to your repo → **Settings** → **Pages**
2. Source: **Deploy from a branch**
3. Branch: **gh-pages** / root
4. Click **Save**

Your appcast will be at: `https://jonathan-oralart.github.io/barcode/appcast.xml`

### 2. Update Feed URL in Xcode

**Already configured!** The `Info.plist` file has been created with:
```
https://jonathan-oralart.github.io/barcode/appcast.xml
```

Just verify in Xcode:
1. Open `barcode.xcodeproj` in Xcode
2. Select the **barcode** target
3. **Build Settings** tab
4. Search for **"Info.plist"**
5. Ensure **Info.plist File** is set to: `barcode/Info.plist`

### 3. Release Scripts

**Already created!** You have two scripts ready to use:

**`release.sh`** - Builds and publishes to GitHub Releases
**`update_appcast.sh`** - Updates appcast.xml on gh-pages branch

Both scripts are already executable and ready to use!

## Publishing Updates

### Every Time You Release:

```bash
# 1. Build and create GitHub release
./release.sh 1.1

# 2. Copy the <item> block from the output
# 3. Edit appcast.xml - add the new item at the top
# 4. Push to gh-pages
git checkout gh-pages
git pull
# Edit appcast.xml with the new <item> at the top
git add appcast.xml
git commit -m "Release v1.1"
git push
git checkout main
```

The `update_appcast.sh` script automatically updates your appcast on the gh-pages branch.

## Complete Workflow for jonathan-oralart/barcode

```bash
# 1. Make your code changes and commit
git add .
git commit -m "Add new features"
git push

# 2. Build and create GitHub release
./release.sh 1.1

# 3. The script outputs FILE_SIZE - copy it, then:
./update_appcast.sh 1.1 <FILE_SIZE>

# Done! ✅
# - GitHub Release created at: github.com/jonathan-oralart/barcode/releases
# - Appcast updated at: jonathan-oralart.github.io/barcode/appcast.xml
# - Users will be notified within 24 hours
```

## How It Works

```
┌─────────────────┐
│   Your App      │  Checks for updates on launch
│   (v1.0)        │──────────────┐
└─────────────────┘              │
                                 ▼
                    ┌─────────────────────────────┐
                    │  GitHub Pages               │
                    │  appcast.xml                │
                    │  "Latest: v1.1"            │
                    └─────────────────────────────┘
                                 │
                    ┌────────────┴───────────────┐
                    ▼                            ▼
         "Update available!"          Downloads from GitHub Releases
         User clicks "Install"        barcode-1.1.zip
                    │
                    ▼
         ┌─────────────────┐
         │   Updated App   │
         │   (v1.1)        │
         └─────────────────┘
```

## First Release Setup

Before you can update, you need an initial release:

```bash
# 1. Create first release
./release.sh 1.0

# 2. Setup appcast on gh-pages
git checkout gh-pages
git pull

# Copy the appcast.xml from main branch (already configured for your repo)
git checkout main appcast.xml

# 3. Update the appcast with your first release
# Copy the FILE_SIZE from the release.sh output, then run:
./update_appcast.sh 1.0 <FILE_SIZE_FROM_OUTPUT>

# Done!
git checkout main
```

Your appcast is already configured for:
- Feed URL: `https://jonathan-oralart.github.io/barcode/appcast.xml`
- Download URL: `https://github.com/jonathan-oralart/barcode/releases/download/...`

## Testing

### Test Before Releasing to Users

1. Build version 1.0
2. Install it
3. Create a test release (1.1-beta)
4. Update appcast with beta
5. Click "Check for Updates" in menu bar
6. App should offer to update

### Common Issues

**"No updates found":**
- Check version in appcast > current version
- Verify appcast.xml is accessible at your GitHub Pages URL
- Check Console.app for Sparkle errors

**"Update downloads but won't install":**
- Verify zip contains `barcode.app` at root level
- Check: `unzip -l barcode-1.1.zip` should show `barcode.app/Contents/...`

**GitHub Pages 404:**
- Wait 1-2 minutes after first push
- Verify gh-pages branch exists
- Check Settings → Pages is enabled

## No Script Method (Manual)

If you prefer doing it manually:

```bash
# 1. Build in Xcode: Product → Archive → Distribute App → Copy App
# 2. Zip it: zip -r barcode-1.1.zip barcode.app
# 3. Get size: ls -l barcode-1.1.zip
# 4. Create release on GitHub, upload zip
# 5. Update appcast.xml with new <item>
# 6. Push appcast.xml to gh-pages branch
```

## Versioning Best Practices

- Use semantic versioning: `1.0`, `1.1`, `2.0`
- Increment for each release
- Users on any version will update to latest

## Security (Optional but Recommended)

To prevent tampering, sign your updates:

```bash
# 1. Install Sparkle tools
brew install sparkle

# 2. Generate keys (ONE TIME ONLY - save private key securely!)
generate_keys
# Outputs: sparkle_eddsa_public.key and sparkle_eddsa_private.key

# 3. Add public key to Xcode Build Settings
# Add: SPARKLE_ED_PUBLIC_KEY = <your_public_key>

# 4. Sign each release
sign_update build/barcode-1.1.zip
# Copy the signature into appcast.xml:
# sparkle:edSignature="SIGNATURE_HERE"
```

---

## Quick Reference for Your Repo

**Feed URL (configured):** `https://jonathan-oralart.github.io/barcode/appcast.xml`  
**GitHub Releases:** `https://github.com/jonathan-oralart/barcode/releases`  
**GitHub Pages Setup:** `https://github.com/jonathan-oralart/barcode/settings/pages`

**Release Command:**
```bash
./release.sh 1.1 && ./update_appcast.sh 1.1 <FILE_SIZE>
```

**You're all set!** Just run the release command whenever you want to publish an update. 🚀

