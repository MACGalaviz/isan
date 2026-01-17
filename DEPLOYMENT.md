# 📦 Deployment & Auto-Update Guide

This document is a comprehensive guide on building, signing, and releasing the **Isan** application. It focuses on a **Self-Hosted** strategy (bypassing App Stores) while maintaining security and update capabilities.

---

## 🏗️ 1. Architecture: The "Store-less" Auto-Update

Since we are distributing the app directly (GitHub Releases), we need a custom mechanism to notify users about updates.

### The Logic
1.  **Source of Truth:** A file named `version.json` hosted on GitHub Pages.
2.  **Artifacts:** The actual files (`.apk`, `.exe`) are stored in **GitHub Releases**.
3.  **Client Check:** The app fetches the JSON on startup. If `remote_version > local_version`, it prompts the user to update.

### Example `version.json`
Place this file in your `web/` folder (or edit it directly in the `gh-pages` branch):
```json
{
  "version": "1.0.1",
  "build_number": 2,
  "changelog": "- Fixed sync bugs\n- Added dark mode",
  "download_url_android": "[https://github.com/USER/isan/releases/download/v1.0.1/app-release.apk](https://github.com/USER/isan/releases/download/v1.0.1/app-release.apk)",
  "download_url_windows": "[https://github.com/USER/isan/releases/download/v1.0.1/Isan_Setup.exe](https://github.com/USER/isan/releases/download/v1.0.1/Isan_Setup.exe)"
}
```

---

## 🌐 2. Web Deployment (GitHub Pages)
Web updates are handled automatically by the browser cache system.

### Tools Required
**Peanut**: A Dart package to build the web folder into a specific git branch.
```bash
dart pub global activate peanut
```

### Deployment Command
Run this from the project root to build and deploy:

```bash
# 1. Build the web app into the 'gh-pages' branch
# Note: We set the base-href to match the repository name
dart pub global run peanut --extra-args "--base-href=/isan/"

# 2. Push the branch to GitHub
git push origin --set-upstream gh-pages
```

---

## 🤖 3. Android Deployment (APK)
For Android to allow an update (installing a new APK over an old one), the app must be Signed with the exact same cryptographic key every time.

### Step A: Generate Keystore (Done once)
*⚠️ Warning: If you lose this file, you cannot update existing apps.*
The file is located at: `android/app/isan-keystore.jks`.

If you need to generate it again (new project):
```bash
& "path\to\keytool.exe" -genkey -v -keystore android/app/isan-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias isan
```

### Step B: Create key.properties
Create a file named `android/key.properties`. **This file must be ignored by Git.**

```properties
storePassword=YOUR_SECURE_PASSWORD
keyPassword=YOUR_SECURE_PASSWORD
keyAlias=isan
storeFile=isan-keystore.jks
```

### Step C: Configure build.gradle
Modify `android/app/build.gradle` to load these properties before the `android` block:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true // Optional: shrinks code
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

### Step D: Build the APK
```bash
flutter build apk --release
```
**Output:** `build/app/outputs/flutter-apk/app-release.apk`

---

## 🪟 4. Windows Deployment (EXE)
Windows builds produce a folder of files. To distribute it cleanly, we wrap it in an Installer.

### Step A: Build the Binaries
```bash
flutter build windows --release
```
**Output:** `build/windows/x64/runner/Release/`

### Step B: Create Installer (Inno Setup)
1. Download and install **Inno Setup**.
2. Open `installers/isan_script.iss`.
3. Ensure the paths in `[Files]` point to your Release folder.
4. Click **Run** to compile.
5. **Output:** `installers/Isan_Setup.exe`.

---

## 🚀 5. Release Workflow Checklist
When you are ready to ship a new version (e.g., v1.0.1):

**NOTE: Remember to update both numbers in the version (e.g., `version: 1.0.0+0`) to the new version (e.g., `version: 1.0.1+1`) before building**

1.  **📝 Bump Version:**
    * Update `pubspec.yaml` (e.g., `version: 1.0.1+2`).

2.  **🍳 Build:**
    * Run `flutter build apk --release`.
    * (Optional) Run `flutter build windows --release`.

3.  **☁️ GitHub Release (Get the Link):**
    * Go to GitHub > Releases > Draft New Release.
    * Tag: `v1.0.1`.
    * **Upload** `app-release.apk` (and `Isan_Setup.exe`).
    * Publish.
    * **COPY the download link** of the assets you just uploaded.

4.  **📢 Update Notification (Final Step):**
    * Edit `web/version.json` (in `gh-pages` branch).
    * Update `"version": "1.0.1"`.
    * Paste the link in `"download_url_android"`.
    * **Deploy to Web:**
      ```bash
      git add .
      git commit -m "🚀 chore(release): release v1.0.1"
      git push origin main
      dart pub global run peanut --extra-args "--base-href=/isan/"
      git push origin gh-pages
      ```
    * *Users will now see the update alert.*