import Quickshell
import QtQuick

// Full-screen, invisible click catcher for anything that isn't dismissed by
// its own focus loss: the small bar dropdowns (volume, notifications,
// power, calendar, wallpaper), which go through PopupGuard/WallpaperState
// and never grab X focus. Whenever one is open, this window covers
// everything below the bar and closes it on any click that isn't on it.
// It's mapped (via the visible binding) before a PopupGuard popup, and new
// windows stack on top, so the popup still renders above it and remains
// clickable.
PanelWindow {
    id: root

    readonly property var openPopup: PopupGuard.current

    // PopupGuard.current only ever changes on claim() (a new popup opening);
    // nothing clears it back to null when a popup hides itself (hover
    // timeout, picking a menu item, re-toggling the same icon off, or this
    // window's own click below). Binding on openPopup.visible too, not just
    // openPopup itself, means we stop covering the screen the instant the
    // popup actually closes instead of staying mapped (and eating every
    // click meant for a real window) until some other popup is claimed.
    visible: (root.openPopup !== null && root.openPopup.visible) || WallpaperState.open
    screen: root.openPopup ? root.openPopup.screen : Quickshell.screens[0]
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    margins.top: Theme.barHeight

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.openPopup)
                root.openPopup.visible = false;
            if (WallpaperState.open)
                WallpaperState.hide();
        }
    }
}
