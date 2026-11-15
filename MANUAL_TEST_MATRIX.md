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
- Return focus regression: in a disposable TextEdit document, Notes note, and Terminal input, copy a harmless test string, summon ClipPanel, select it, and press Return. Confirm the panel closes, exactly one copy is inserted at the original caret, and subsequent typing stays in the destination. In Terminal, do not submit the test text as a command.
- Repeat the focus check with Shift-Return (plain text), Option-Return (copy only), Escape, and auto-paste disabled. Copy-only must close the panel and return keyboard focus without inserting text.
- During a delayed paste, switch to another app; confirm Command-V is not sent to that other app. Reopen the panel quickly after pasting and confirm an older paste completion does not close the new panel.
- Spaces and a full-screen application.
- Onboarding: with auto-paste enabled and permission denied or deferred, Continue on Privacy and Start Using ClipPanel on Ready must keep setup on Privacy and request permission. Selecting Ready directly must not bypass the check. Grant permission in System Settings and return; status must refresh. Explicit Copy Only must disable auto-paste and allow setup to finish without permission.
- Permission allowed, denied, and deferred; denied auto-paste must visibly explain the blocker and offer Option-Return for copying.
- Source app quits before selecting an item.
- 0, 1, 500, and 1,000-record histories; long text and near-limit images; rapid repeated copies.
- Pause/resume, ignored marker types, self-write suppression, retention with pins, clear history, launch at login, light/dark/increased contrast, and VoiceOver basics.
- Library: edit text and confirm it saves a new record; tags, snippets, custom find/replace commands, normal/encrypted collections, and sequential queue pasting.
- Archive: plain import/export, encrypted archive rejection with a wrong password, and manual encrypted-folder sync using a disposable folder.
- Text-caret placement: with Accessibility permission granted and denied; confirm denied permission falls back to pointer placement and no prompt appears without pressing the Settings button.
- App Shortcuts and `clipctl open`, `clipctl library`, and `clipctl search <query>` route to the expected local view.

Do not automate privacy permission resets: they are destructive system state changes.
