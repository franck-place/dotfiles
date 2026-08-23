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

    visible: root.openPopup !== null
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
