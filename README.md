# আমার হিসাব (Amar Hishab)
Offline Flutter Android app: income/expense, budgets, debts, savings, reports, JSON backup/restore, CSV/PDF, optional PIN.
No internet permission, no cloud, no AI.

## Get the APK (no Flutter install needed)
1. Push this folder to a GitHub repository (branch `main`).
2. GitHub → Actions → "Build APK" (runs on push; or "Run workflow").
3. Open the finished run → Artifacts → `amar-hishab-apk` → download zip → `app-release.apk`.

## Build locally
    flutter create . --org com.amarhishab --project-name amar_hishab --platforms android   # once (keeps lib/ & pubspec; delete test/widget_test.dart)
    flutter pub get && dart run flutter_launcher_icons
    flutter analyze && flutter test && flutter build apk --release
APK: build/app/outputs/flutter-apk/app-release.apk

## Signing
The release build is signed with the debug key by default: fine for personal installs. For Play Store, create a keystore, keep it and `android/key.properties` OUT of git (already in .gitignore of generated project), and reference it from android/app/build.gradle.

## Install
Copy APK to phone → open → allow "Install unknown apps" for your file manager → Install.

## Backup / Restore
Settings → ব্যাকআপ (JSON) → choose where to save. Restore: Settings → পুনরুদ্ধার → pick file; the file is validated and you must confirm before current data is replaced.

## Notes
Debts are tracked separately and never counted as income/expense. Savings goals are not expenses. Balance = opening + all income − all expenses.
