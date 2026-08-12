# Publishing `json5_plus` to pub.dev

Follow these steps to publish a new version of the `json5_plus` package to [pub.dev](https://pub.dev).

---

## 1. Commit and Push Changes to Git

Ensure all working files (code, tests, `pubspec.yaml`, `CHANGELOG.md`) are committed and pushed to GitHub:

```bash
git add .
VERSION=$(grep '^version:' pubspec.yaml | cut -d ' ' -f2)
git commit -m "Prepare release v$VERSION"
git push origin main
```

---

## 2. Perform a Dry Run Verification

Run a dry run of the publish command to check for any static analysis issues, formatting errors, or package configuration warnings:

```bash
dart pub publish --dry-run
```

Ensure the dry run completes with no errors or warnings before proceeding.

---

## 3. Publish to pub.dev

Execute the publish command:

```bash
dart pub publish
```

1. Review the summary of files to be uploaded.
2. Type `y` when prompted to confirm the publication.
3. Complete any browser-based authentication if prompted by Google Account sign-in.

---

> [!CAUTION]
> Package publishing to `pub.dev` is permanent and versions cannot be deleted or overwritten once published.
