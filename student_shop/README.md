BMC E-Commerce (CueHaven Shop) Setup
Guide
A simple Flutter app with Supabase. This guide shows how to download, run, and install it.
Requirements
Flutter SDK (https://docs.flutter.dev/get-started/install)
Google Chrome
VS Code orAndroid Studio
Check that your setup is okay:
flutter doctor
How to Download the Code
Option A: Download ZIP
1. Go to the BMC-E-COMMERCE GitHub repo.
2. Click the green Code button.
3. Click Download ZIP.
4. Extract the ZIP file.
OptionB: Git clone
git clone https://github.com/<username>/BMC-E-COMMERCE.git
cd BMC-E-COMMERCE/student_shop
Option C: PowerShell only (Windows, no Git needed)
Invoke-WebRequest -Uri "https://github.com/<username>/BMC-ECOMMERCE/archive/refs/heads/main.zip" -OutFile "BMC-E-COMMERCE.zip"
Expand-Archive -Path "BMC-E-COMMERCE.zip" -DestinationPath "."
Replace <username> with the GitHub username of the repo owner.
BMC E-Commerce (Student Shop) Setup Guide
How to Run the App
cd BMC-E-COMMERCE-main/student_shop
flutter pub get
flutter run -d chrome
The app will open in Chrome.
How to Download the APK (Android)
1. Open the BMC-E-COMMERCE GitHub repo on your phone.
2. Go to Releases (on the right side of the page).
3. Click the latest release.
4. Under Assets, click app-release.apk to download it.
Using PowerShell instead:
Invoke-WebRequest -Uri "https://github.com/<username>/BMC-ECOMMERCE/releases/latest/download/app-release.apk" -OutFile "app-release.apk"
How to Installthe APK
1. Open the downloaded app-release.apk .
2. If you see "Install blocked", tap Settings and turn on Allow from this source.
3. Go back and tap Install.
4. When it's done, tap Open to use the app.
If it won't install, make sure you're on an Android phone and have enough storage.
For Developers: How toBuild the APK
cd BMC-E-COMMERCE-main/student_shop
flutter pub get
flutter build apk --release
The APK will be at:
student_shop/build/app/outputs/flutter-apk/app-release.apk
BMC E-Commerce (Student Shop) Setup Guide
To let others download it, upload it to GitHub: Releases → Draft a new release → attach
app-release.apk → Publish release.
CommonErrors
No pubspec.yaml file found : You are in the wrong folder. Go into student_shop .
flutter: command not found : Flutter is not installed or not in your PATH.
SDK version error: Run flutter upgrade .
