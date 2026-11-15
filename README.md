# ClipPanel

ClipPanel is a local-first macOS clipboard history utility. Press its global shortcut, search your recent clips, then paste back into the app you were using. It is an original Swift implementation and is not affiliated with CopyQ.

## Requirements

- macOS 14.0 or later
- Xcode 26.3 / Swift 6.2 or a compatible newer Xcode
- XcodeGen (`brew install xcodegen`) only when regenerating the project after editing `project.yml`

## Build, test, and run

```bash
xcodegen generate
xcodebuild -project ClipPanel.xcodeproj -scheme ClipPanel -configuration Debug -derivedDataPath .build/XcodeDerivedData test CODE_SIGNING_ALLOWED=NO
./script/build_and_run.sh --verify
```

`script/build_and_run.sh` builds an actual `.app` bundle and opens it. It also supports `--logs`, `--telemetry`, and `--debug`.

## Everyday controls

- **Return / Enter:** paste the selected clip. **Shift-Return:** paste plain text. **Option-Return:** copy only.
- **Command-1…9:** paste the corresponding displayed result, including search and type filters.
- **Up/Down:** browse results. **Space** previews while browsing; **Command-Y** or the eye button previews at any time. Escape closes the preview first, then the panel. Normal spaces remain available while typing a search.
- **All / Text / Images / Files:** narrow the list without typing filter syntax. Search supports fuzzy matching and highlights matches.
- The text-action menu creates and copies a transformed clip (trim whitespace, case changes, plain text, URL cleanup, or web URL extraction). The original remains in history.
- **Pause For…** in the menu bar or Settings pauses for 15 minutes, 1 hour, or 4 hours; copies made during a pause are skipped on resume.
- **Privacy → Ignored Applications:** choose installed or running apps to exclude. Existing history is unchanged.
- **History → Delete old history:** optionally expire disposable history after a chosen age. Pinned clips, snippets, favorites, and clips in collections are protected from automatic cleanup.
- **About:** shows the bundled version, opens the beta releases page in your browser, and offers Restart ClipPanel. There are no background update requests.

If auto-paste becomes unavailable and copy-only fallback is enabled, the clip remains on the clipboard and a nonactivating notice tells you to press Command-V. Turning fallback off prevents clipboard replacement when failure is known before restoration; if focus changes after restoration, the restored clip is kept safely.

## Permissions and privacy

On first launch, ClipPanel explains each capability before enabling it:

- Clipboard monitoring is off until enabled in onboarding. It reads supported clipboard data locally while enabled.
- Auto-paste is optional. Onboarding verifies permission before finishing with auto-paste enabled, or lets you explicitly choose Copy Only. Permission requests happen only from onboarding, Settings, or an explicit paste action. When permission is missing, the configured copy-only fallback is honored and the panel explains the outcome; Option-Return always copies without auto-pasting.
- Launch at login is optional and uses `SMAppService.mainApp`.

After approving auto-paste in macOS Settings, quit and reopen ClipPanel if it still reports permission required. Local ad-hoc builds can require re-approval after rebuilding; approve the exact running copy using **Privacy → Show This ClipPanel in Finder**.

ClipPanel does not send network requests, include analytics, create accounts, or log clipboard values/search queries. See [PRIVACY.md](PRIVACY.md).

The Library adds saved snippets, editable text saved as new clips, tags, collections, transformations, queues, and archive tools. Its optional folder sync is a manual, password-encrypted archive exchange; see [SYNC_THREAT_MODEL.md](SYNC_THREAT_MODEL.md).

## Automation

The built `clipctl` executable opens the same local automation routes as Shortcuts:

```bash
clipctl open
clipctl library
clipctl search "type:image tag:release"
```

ClipPanel also publishes Open Clipboard, Search Clipboard, and Open Library App Shortcuts. All three only route into the local app; they do not expose clipboard content to a network service.

## Architecture

SwiftUI owns app state, settings, onboarding, and the panel content. The AppKit boundary is intentionally narrow: `NSPasteboard` capture/restore, a reusable keyable `NSPanel`, prior-app activation, and CGEvent Command-V posting. SwiftData stores record metadata and external encoded payload data. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Development notes

- Change `project.yml`, then run `xcodegen generate`; do not edit `ClipPanel.xcodeproj/project.pbxproj` directly.
- The package lock is committed in `ClipPanel.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` and pins KeyboardShortcuts to a stable release.
- Use [MANUAL_TEST_MATRIX.md](MANUAL_TEST_MATRIX.md) for real-app/permission verification. Permission resets are deliberately not automated because they alter system state.
- `ClipPanelUITests` remains available for future accessibility/window automation. The default test scheme runs deterministic unit tests; menu-bar interaction and OS permission flows are covered by the manual matrix because they depend on real user session state.
