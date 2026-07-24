import AppKit
import ApplicationServices

/// Reads only the focused control's selected text range in response to opening the panel. It is
/// opt-in through the Text Caret placement preference and falls back to the pointer if the target
/// app does not expose a caret rectangle.
@MainActor
final class AccessibilityCaretService {
    var isTrusted: Bool { AXIsProcessTrustedWithOptions(nil) }

    func requestAccess() -> Bool {
        return AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func caretPoint() -> CGPoint? {
        guard isTrusted else { return nil }
        let systemElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedElement = focusedValue as! AXUIElement? else { return nil }

        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let range = rangeValue as! AXValue? else { return nil }
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focusedElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &boundsValue
        ) == .success,
        let bounds = boundsValue as! AXValue? else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(bounds, .cgRect, &rect), !rect.isEmpty else { return nil }
        // AX screen coordinates are top-left based. Use the display containing the rect's X
        // coordinate to return the bottom-left based coordinate expected by AppKit positioning.
        let display = NSScreen.screens.first { screen in
            rect.midX >= screen.frame.minX && rect.midX <= screen.frame.maxX
        } ?? NSScreen.main
        guard let display else { return nil }
        return CGPoint(x: rect.maxX, y: display.frame.maxY - rect.minY)
    }
}
