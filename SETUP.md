# FileTag - Setup Guide

## What this is
A virtual file-tagging system. Files stay exactly where they are on your
device. The app only stores **references** (path + tags) in a local
SQLite database. One exam file can carry the tags "Physics",
"Exams 2025", and "Form Six" at the same time — it shows up in all
three virtual folders, with zero duplication on disk.

## 1. Create the Flutter project shell
This scaffold has `lib/` and `pubspec.yaml` but not the platform folders
(`android/`, `ios/`), which Flutter generates for you:

```bash
flutter create --org com.marwamj filetag_shell
# then copy this lib/ and pubspec.yaml into filetag_shell, overwriting theirs
cp -r lib/* filetag_shell/lib/
cp pubspec.yaml filetag_shell/pubspec.yaml
cd filetag_shell
flutter pub get
```

## 2. Android 13 permissions (critical step)
Open `android/app/src/main/AndroidManifest.xml` and add, inside
`<manifest>` but **above** `<application>`:

```xml
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

Why: Android 13's `READ_MEDIA_IMAGES/VIDEO/AUDIO` only cover media —
not PDFs, docs, zips, etc. `MANAGE_EXTERNAL_STORAGE` ("All files
access") is the one that gives a general file manager full visibility.
The app requests it at runtime; you'll be sent to a system Settings
screen once to flip it on (this is standard for file manager apps,
not a bug).

Also inside `<application>`, if you see `android:requestLegacyExternalStorage`,
you can remove it — irrelevant on Android 13+.

## 3. Build & run (from Termux + GitHub Codespaces, your usual flow)
```bash
flutter pub get
flutter build apk --release
```
The APK lands in `build/app/outputs/flutter-apk/app-release.apk`.
Push it to GitHub, pull it on your phone, install, done — same loop
you used for StudyDesk, just producing an APK instead of a PWA.

## 4. First run on your phone
1. Open the app, tap **Scan device storage**.
2. It'll prompt for "All files access" — allow it in Settings.
3. Tap **Manage tags** → create "Physics", "Exams 2025", etc.
4. Open a tag → tap **+** → select files → **Add**.
   Same file can be added to as many tags as you want.

## Where to extend next
- Auto-tagging rules (filename contains "2025" → auto-tag "Exams 2025")
  would go in `StorageService.scanAndIndex` — check `baseName` while
  scanning and call `db.tagFile()` automatically.
- Nested categories (e.g. Physics > Exams > 2025) would need a
  `parent_tag_id` column on the `tags` table — the join-table logic
  in `db_helper.dart` stays the same.
- Search bar: a `LIKE` query on `files.name` is enough to start.
