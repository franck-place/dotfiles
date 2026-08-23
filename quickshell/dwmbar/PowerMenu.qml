import Quickshell
import Quickshell.Io
import QtQuick

// Power icon in the bar; click opens a small dropdown instead of the old
// dmenu-based power-menu script.
Item {
    id: pm

    required property var bar

    width: 26
    height: 22

    readonly property var actions: [
        { label: "Restart",  icon: "\u{f0709}", cmd: ["systemctl", "reboot"] },
        { label: "Shutdown", icon: "\u{f0425}", cmd: ["systemctl", "poweroff"] },
        { label: "Logout",   icon: "\u{f0343}", cmd: ["pkill", "-TERM", "-x", "dwm"] }
    ]

    function setShown(shown) {
        popup.visible = shown;
    }

    IpcHandler {
        target: "power"

        function toggle() {
            pm.setShown(!popup.visible);
        }

        function show() {
            pm.setShown(true);
        }

        function hide() {
            pm.setShown(false);
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: pmMouse.containsMouse ? Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            text: "⏻"
            color: Theme.fg
            font.pixelSize: Theme.fontSize + 2
        }

        MouseArea {
            id: pmMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                const p = pm.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + pm.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
        }
    }

    PopupWindow {
        id: popup

        anchor.window: pm.bar
        implicitWidth: 170
        implicitHeight: popupCol.implicitHeight + 20
        visible: false
        color: "transparent"

        HoverHandler {
            id: popupHover
        }

        Timer {
            interval: 4000
            running: popup.visible && !popupHover.hovered
            onTriggered: popup.visible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.popupBg
            border.color: Theme.popupBorder
            border.width: 1

            Column {
                id: popupCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                spacing: 2

                Repeater {
                    model: pm.actions

                    delegate: Rectangle {
                        id: entryRoot
                        required property var modelData

                        width: popupCol.width
                        height: 32
                        radius: 8
                        color: itemMouse.containsMouse ? Theme.hover : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize
                                color: Theme.fg
                                text: entryRoot.modelData.icon
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: entryRoot.modelData.label
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                popup.visible = false;
                                Quickshell.execDetached(entryRoot.modelData.cmd);
                            }
                        }
                    }
                }
            }
        }
    }
}
