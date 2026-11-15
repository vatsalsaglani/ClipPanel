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

## Keyboard, recovery, privacy, and update regression checks

- With active type/search filters, Command-1 through Command-9 must paste the correspondingly numbered displayed row. Hold arrows to verify selection remains visible; out-of-range shortcuts must do nothing.
- Type a multiword query normally, browse with arrows and press Space to preview, then type again. Confirm text entry, Command-Y, and the two-step Escape behavior. Preview long text and a large image; the original paste must remain complete.
- Disable auto-paste permission: with copy fallback enabled, select a clip and verify a visible nonactivating copy notice and manual Command-V. With fallback disabled, verify the current clipboard is unchanged. Option-Return must still copy. Switch apps or copy a different item during the paste delay and verify no misplaced keystroke or clipboard overwrite occurs.
- Use each text action, including Extract URLs with repeated links and text without links; confirm the original record stays intact and successful actions create/copy the transformed result.
- Pause monitoring for a timed duration; copy while paused and resume manually or at the deadline. Confirm paused copies are not captured. Relaunch during a pause; confirm the remaining pause persists. Choose an ignored running app and verify only new copies are excluded.
- In disposable test history, enable age expiry and lower the count limit; confirm expired unsaved history is removed while pins, snippets, favorites, collection items, and encrypted items remain. Do not enable expiry on real history just to test it.
- About must display the bundle version and open the releases page only on request. Restart must reopen the same bundle, leave exactly one ClipPanel running, and preserve history/settings. Confirm permission recovery after a manual macOS grant and restart.
