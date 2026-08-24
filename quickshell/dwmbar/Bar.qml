import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

// The only bar: dwm's own bar is fully disabled (showbar=0, showsystray=0
// in config.h). dwm still reserves Theme.barHeight px of screen space for
// it in updatebarpos() even though nothing of its own is ever drawn there --
// see dwm.c's NetWMWindowTypeDock handling in manage() for how this window
// itself is kept unmanaged/floating on top instead of tiled.
PanelWindow {
    id: bar

    required property var modelData
    readonly property var mon: DwmState.monitorFor(bar.screen)

    screen: modelData
    aboveWindows: true
    color: Theme.barBg

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight

    function nextLayoutKey() {
        const l = bar.mon ? bar.mon.layout : "[]=";
        if (l === "[]=")
            return "super+f";
        if (l === "><>")
            return "super+m";
        return "super+t";
    }

    function sendKey(combo) {
        if (bar.mon)
            DwmState.keyOnMonitor(bar.mon.num, combo);
        else
            DwmState.key(combo);
    }

    // ---- left: settings, tags, layout, focused window title ----
    Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        SettingsMenu {
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 1
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.popupBorder
        }

        Repeater {
            model: 9

            delegate: Rectangle {
                id: tagPill
                required property int index

                readonly property bool tagSelected: bar.mon ? (bar.mon.tags & (1 << index)) !== 0 : index === 0
                readonly property bool tagOccupied: bar.mon ? (bar.mon.occ & (1 << index)) !== 0 : false
                readonly property bool tagUrgent: bar.mon ? (bar.mon.urg & (1 << index)) !== 0 : false

                width: 22
                height: 22
                radius: 5
                color: tagPill.tagUrgent ? Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.35)
                     : tagPill.tagSelected ? Theme.accent
                     : tagMouse.containsMouse ? Theme.hover
                     : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: tagPill.index + 1
                    color: tagPill.tagSelected ? Theme.fgSel : (tagPill.tagOccupied ? Theme.fg : Theme.fgDim)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: tagPill.tagOccupied
                }

                MouseArea {
                    id: tagMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        const combo = (mouse.button === Qt.RightButton ? "super+ctrl+" : "super+") + (tagPill.index + 1);
                        bar.sendKey(combo);
                    }
                }
            }
        }

        Item { width: 8; height: 1 }

        Rectangle {
            width: layoutText.implicitWidth + 12
            height: 22
            radius: 5
            color: layoutMouse.containsMouse ? Theme.hover : "transparent"

            Text {
                id: layoutText
                anchors.centerIn: parent
                text: bar.mon ? bar.mon.layout : "[]="
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            MouseArea {
                id: layoutMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.sendKey(bar.nextLayoutKey())
            }
        }

        Item { width: 10; height: 1 }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, clock.x - (leftRow.x + x) - 16))
            text: bar.mon ? bar.mon.title : ""
            color: bar.mon && bar.mon.selected ? Theme.fg : Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
    }

    ClockWidget {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        bar: bar
    }

    // ---- right: tray, volume, power ----
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        MediaWidget {
            id: mediaWidget
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }

        Rectangle {
            width: 1
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.popupBorder
            visible: mediaWidget.visible
        }

        Repeater {
            model: SystemTray.items

            delegate: Rectangle {
                required property var modelData

                width: 26
                height: 22
                radius: 6
                color: trayMouse.containsMouse ? Theme.hover : "transparent"

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: modelData.icon
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            if (modelData.onlyMenu && modelData.hasMenu)
                                modelData.display(bar, mouse.x, mouse.y);
                            else
                                modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (modelData.hasMenu) {
                            modelData.display(bar, mouse.x, mouse.y);
                        }
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.popupBorder
            visible: SystemTray.items.values.length > 0
        }

        VolumeWidget {
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }

        NotificationCenter {
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }

        PowerMenu {
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }
    }

    WallpaperPicker {
        bar: bar
    }
}
