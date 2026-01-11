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
Place this file in your `web/` folder so it gets deployed to GitHub Pages:
```json
{
  "version": "1.0.1",
  "build_number": 2,
  "changelog": "- Fixed sync bugs\n- Added dark mode",
  "download_url_android": "[https://github.com/USER/isan/releases/download/v1.0.1/app-release.apk](https://github.com/USER/isan/releases/download/v1.0.1/app-release.apk)",
  "download_url_windows": "[https://github.com/USER/isan/releases/download/v1.0.1/Isan_Setup.exe](https://github.com/USER/isan/releases/download/v1.0.1/Isan_Setup.exe)"
}
🌐 2. Web Deployment (GitHub Pages)
Web updates are handled automatically by the browser cache system.

Tools Required
Peanut: A Dart package to build the web folder into a specific git branch.

Bash

dart pub global activate peanut
Deployment Command
Run this from the project root to build and deploy:

Bash

# 1. Build the web app into the 'gh-pages' branch
# Note: We set the base-href to match the repository name
dart pub global run peanut --extra-args "--base-href=/isan/"

# 2. Push the branch to GitHub
git push origin --set-upstream gh-pages
🤖 3. Android Deployment (APK)
For Android to allow an update (installing a new APK over an old one), the app must be Signed with the exact same cryptographic key every time.

Step A: Generate Keystore (Do this once)
Run this command in the terminal. Keep the password safe!

Bash

keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
Step B: Create key.properties
Create a file named android/key.properties. This file must not be committed to Git (add it to .gitignore).

Properties

storePassword=<YOUR_PASSWORD>
keyPassword=<YOUR_PASSWORD>
keyAlias=upload
storeFile=upload-keystore.jks
Step C: Configure build.gradle
Modify android/app/build.gradle to load these properties before the android block:

Groovy

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
            // ...
        }
    }
}
Step D: Build the APK
Bash

flutter build apk --release
Output: build/app/outputs/flutter-apk/app-release.apk

🪟 4. Windows Deployment (EXE)
Windows builds produce a folder of files. To distribute it cleanly, we wrap it in an Installer.

Step A: Build the Binaries
Bash

flutter build windows --release
Output: build/windows/x64/runner/Release/

Step B: Create Installer (Inno Setup)
Download and install Inno Setup.

Create a new script (isan.iss).

Point the "Source" to your Release folder.

Compile to generate Isan_Setup.exe.

🚀 5. Release Workflow Checklist
When you are ready to ship v1.0.1:

[ ] Bump Version: Update pubspec.yaml (e.g., version: 1.0.1+2).

[ ] Update JSON: Update web/version.json with the new version and save.

[ ] Build Web: Run peanut & git push.

[ ] Build Android: Run flutter build apk --release.

[ ] Build Windows: Run flutter build windows --release & Compile Installer.

[ ] GitHub Release:

Go to GitHub > Releases > Draft New Release.

Tag: v1.0.1.

Upload app-release.apk and Isan_Setup.exe.

Publish.
