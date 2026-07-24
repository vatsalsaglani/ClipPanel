# ClipPanel manual test matrix

Run this against the real app bundle built by `./script/build_and_run.sh --verify`. Record the macOS version, signing identity, and whether post-event permission is granted, denied, or deferred.

| App | Text | Rich text | URL | Image | Multiple files | Auto-paste | Copy-only |
|---|---|---|---|---|---|---|---|
| TextEdit | ☐ | ☐ | ☐ | ☐ | N/A | ☐ | ☐ |
| Safari | ☐ | ☐ | ☐ | ☐ | N/A | ☐ | ☐ |
| Finder | ☐ | N/A | N/A | N/A | ☐ | ☐ | ☐ |
| Terminal | ☐ | ☐ | ☐ | N/A | Paths | ☐ | ☐ |
| Xcode | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

Also verify:

- Panel focus, all keyboard shortcuts, and pointer positioning at every edge/corner of each attached display.
- Spaces and a full-screen application.
- Permission allowed, denied, and deferred; ensure denied auto-paste is a non-destructive copy-only result.
- Source app quits before selecting an item.
- 0, 1, 500, and 1,000-record histories; long text and near-limit images; rapid repeated copies.
- Pause/resume, ignored marker types, self-write suppression, retention with pins, clear history, launch at login, light/dark/increased contrast, and VoiceOver basics.
- Library: edit text and confirm it saves a new record; tags, snippets, custom find/replace commands, normal/encrypted collections, and sequential queue pasting.
- Archive: plain import/export, encrypted archive rejection with a wrong password, and manual encrypted-folder sync using a disposable folder.
- Text-caret placement: with Accessibility permission granted and denied; confirm denied permission falls back to pointer placement and no prompt appears without pressing the Settings button.
- App Shortcuts and `clipctl open`, `clipctl library`, and `clipctl search <query>` route to the expected local view.

Do not automate privacy permission resets: they are destructive system state changes.
