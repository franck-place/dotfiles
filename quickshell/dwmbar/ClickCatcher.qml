import Quickshell
import QtQuick

// Full-screen, invisible click catcher for the small bar dropdowns (volume,
// notifications, power, calendar) that go through PopupGuard. Those are
// PopupWindows anchored near a bar icon and never grab X focus, so the
// Window.active trick used by Launcher/WallpaperPicker/SettingsWindow
// doesn't apply -- instead, whenever PopupGuard has an open popup, this
// window covers everything below the bar and closes it on any click that
// isn't on the popup itself. It's mapped (via the visible binding) before
// the popup, and new windows stack on top, so the popup still renders above
// it and remains clickable.
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
    visible: root.openPopup !== null && root.openPopup.visible
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
        }
    }
}
