# 📱 How to Publish to Google Play Store

## Prerequisites
- Google account
- $25 one-time registration fee for Google Play Developer account
- Android Studio or command line tools

---

## Step 1: Create a Signing Key (One-time setup)

**Run this command in your terminal:**

```bash
cd mobile_app/android
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**When prompted, enter:**
- Password: Create a strong password (save it securely!)
- Name, Organization, etc.: Your details
- **Important:** Save the password and keystore location!

**Create a file to store your password:**

```bash
cd mobile_app/android
echo "YOUR_KEYSTORE_PASSWORD" > key.properties
chmod 600 key.properties
```

---

## Step 2: Configure Signing in Your App

The `build.gradle.kts` file has been updated to use your keystore. Make sure:
- Your keystore is at `~/upload-keystore.jks`
- Your `key.properties` file has the correct password

---

## Step 3: Build the Release App Bundle (AAB)

**Run this command:**

```bash
cd mobile_app
flutter build appbundle --release
```

**Output location:** `mobile_app/build/app/outputs/bundle/release/app-release.aab`

This file is what you'll upload to Play Store.

---

## Step 4: Create Google Play Developer Account

1. Go to https://play.google.com/console/signup
2. Pay the $25 registration fee (one-time)
3. Complete your developer profile

---

## Step 5: Create Your App in Play Console

1. Log in to https://play.google.com/console
2. Click **"Create app"**
3. Fill in:
   - **App name:** "arXiv Trend Advisor"
   - **Default language:** English
   - **App or game:** App
   - **Free or paid:** Free
   - **Declarations:** Check all that apply
4. Click **"Create app"**

---

## Step 6: Upload Your App Bundle

1. In Play Console, go to your app
2. Click **"Production"** (or "Testing" → "Internal testing" for testing first)
3. Click **"Create new release"**
4. Click **"Upload"** and select your `app-release.aab` file
5. Fill in **Release name:** "1.0.0" (or your version)
6. Click **"Save"**

---

## Step 7: Complete Store Listing

Go to **"Store presence" → "Main store listing"** and fill in:

- **App name:** arXiv Trend Advisor
- **Short description:** (80 chars max)
  ```
  Predict research trends from your paper title and abstract
  ```
- **Full description:** (4000 chars max)
  ```
  arXiv Trend Advisor helps researchers understand where their work fits in the academic landscape. Simply enter your paper's title and abstract, and get instant insights about:

  • Primary research domain classification
  • Domain confidence scores
  • Category growth trends on arXiv
  • Suggested keywords for better discoverability
  • Related research domains

  Perfect for researchers preparing submissions, exploring new fields, or understanding the academic landscape.

  Powered by arxiv-trend-predictor API.
  ```
- **App icon:** Upload 512x512 PNG (required)
- **Feature graphic:** Upload 1024x500 PNG (required)
- **Screenshots:** Upload at least 2 screenshots (phone format)
- **Privacy Policy URL:** (Required) Create a simple privacy policy page

---

## Step 8: Complete App Content

1. **Content rating:** Complete the questionnaire
2. **Target audience:** Select appropriate age groups
3. **Data safety:** Fill out what data your app collects (if any)
4. **Ads:** Select if your app shows ads (probably "No")

---

## Step 9: Submit for Review

1. Go back to **"Production"** (or your testing track)
2. Review your release
3. Click **"Review release"**
4. Click **"Start rollout to Production"** (or "Save" for testing)

**Review time:** Usually 1-7 days for new apps

---

## Step 10: Monitor Your App

- Check **"Dashboard"** for review status
- Respond to any feedback from Google
- Once approved, your app will be live!

---

## Quick Commands Reference

```bash
# Build release bundle
flutter build appbundle --release

# Test release build locally
flutter build apk --release
flutter install --release

# Check your app version
cat pubspec.yaml | grep version
```

---

## Troubleshooting

**"App not signed" error:**
- Make sure `key.properties` exists and has correct password
- Verify keystore path in `build.gradle.kts`

**"Version code already exists":**
- Increment version in `pubspec.yaml`: `version: 1.0.1+2`
- Rebuild: `flutter build appbundle --release`

**"Missing privacy policy":**
- Create a simple page on GitHub Pages or your website
- Or use a free service like https://www.freeprivacypolicy.com/

---

## Important Notes

- **Keystore password:** Never lose it! You can't update your app without it.
- **Version code:** Must increase with each release (the `+1` part in `version: 1.0.0+1`)
- **Testing:** Use "Internal testing" track first before production
- **Privacy Policy:** Required for all apps on Play Store

Good luck! 🚀
