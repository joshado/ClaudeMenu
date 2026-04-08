---
name: release
description: Build and release a new version of ClaudeMenu
user_invocable: true
argument: version number (e.g. "1.2.0")
---

# Release ClaudeMenu

Build, bundle, and publish a new release of ClaudeMenu to GitHub.

## Steps

1. **Parse the version** from the argument (e.g. "1.2.0"). If no version is provided, ask the user.

2. **Build the project** in release mode:
   ```bash
   cd ClaudeMenu && swift build -c release --arch arm64 --arch x86_64
   ```

3. **Copy binaries** into the app bundle:
   ```bash
   cp ClaudeMenu/.build/apple/Products/Release/ClaudeMenu ClaudeMenu.app/Contents/MacOS/ClaudeMenu
   cp ClaudeMenu/.build/apple/Products/Release/claude-statusline ClaudeMenu.app/Contents/MacOS/claude-statusline
   cp ClaudeMenu/.build/apple/Products/Release/claude-statusline ClaudeMenu.app/Contents/Resources/claude-statusline
   ```

4. **Update `ClaudeMenu.app/Contents/Info.plist`** — set both `CFBundleVersion` and `CFBundleShortVersionString` to the new version.

5. **Codesign the app bundle**:
   ```bash
   codesign --force --sign "Apple Development: Thomas Haggett (54WJHYC472)" --deep ClaudeMenu.app
   ```
   Verify with `codesign --verify --deep --strict ClaudeMenu.app`.

6. **Update `README.md`** — rename the "Unreleased" section in the Changelog to the new version number (e.g. `### v1.2.0`). If there is no "Unreleased" section, add a new version section above the previous version with a summary of changes from `git log` since the last tag.

7. **Commit** the README and Info.plist changes with message: `Release v{version}`

8. **Push** to origin/main.

9. **Create the zip**:
   ```bash
   zip -r ClaudeMenu-v{version}.zip ClaudeMenu.app/
   ```

10. **Create the GitHub release** using `gh release create v{version}` with the zip as an asset. Generate release notes from the changelog section for this version.

11. **Clean up** — remove the local zip file.

12. Report the release URL to the user.
