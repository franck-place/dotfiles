import Quickshell
import QtQuick

// openSUSE Geeko icon in the bar; opens the full settings window (see
// SettingsWindow.qml, a separate top-level screen-centered window) via a
// self-directed IPC call -- the same mechanism dwm's keybinds use to reach
// quickshell from outside.
Item {
    id: settingsIcon

    width: 26
    height: 22

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: iconMouse.containsMouse ? Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: "#73ba25"
            text: "\u{f314}" // openSUSE Geeko
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/dwmbar", "call", "settings", "toggle"])
        }
    }
}
