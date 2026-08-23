import Quickshell
import Quickshell.Io
import QtQuick

// Wallpaper picker: a small window anchored flush under the bar, spanning
// only its own column -- not the whole bar-width strip, and not a floating
// popup panel either (no border/radius, exact bar background color) -- so
// it reads as a small part of the bar dropping down, not a menu.
//
// The window itself maps at its final size immediately; "growing open" is
// a clipped reveal animation of the content *inside* it, not a live resize
// of the actual window. Animating a real X11 top-level window's geometry
// every frame (as this used to do, briefly, as part of the whole bar) is
// inherently choppy -- each step is a real ConfigureWindow round-trip plus
// a GLX surface reallocation. A fixed-size window with an animated clip
// mask is pure GPU-composited scene-graph work instead.
PopupWindow {
    id: root

    required property var bar

    anchor.window: root.bar
    anchor.rect.x: Math.round((root.bar.width - WallpaperState.panelWidth) / 2)
    anchor.rect.y: Theme.barHeight

    implicitWidth: WallpaperState.panelWidth
    implicitHeight: WallpaperState.contentHeight

    // ClickCatcher also reacts to WallpaperState.open, directly and
    // synchronously -- if this window's own visible did too, both windows
    // would request mapping in the same instant with no guaranteed order,
    // and whichever X happened to stack on top would eat every click
    // (matching exactly what selecting a wallpaper looked like: the click
    // never reached the grid's own MouseArea, so it just closed like an
    // outside click). Mapping this window a beat after ClickCatcher
    // guarantees it stacks above it instead, the same way PopupGuard's own
    // popups stay reliably on top of it.
    property bool mapped: false
    visible: mapped || closeTimer.running
    color: "transparent"

    Connections {
        target: WallpaperState
        function onOpenChanged() {
            if (WallpaperState.open) {
                if (PopupGuard.current)
                    PopupGuard.current.visible = false;
                openTimer.restart();
            } else {
                root.mapped = false;
                closeTimer.restart();
            }
        }
    }

    Timer {
        id: openTimer
        interval: 20
        onTriggered: root.mapped = true
    }

    // keeps the window mapped for exactly as long as the reveal mask takes
    // to collapse back to 0, so the close reads as a motion instead of a pop.
    Timer {
        id: closeTimer
        interval: 170
    }

    IpcHandler {
        target: "wallpaper"

        function toggle() { WallpaperState.toggle(); }
        function show() { WallpaperState.show(); }
        function hide() { WallpaperState.hide(); }
    }

    Rectangle {
        id: revealMask
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: WallpaperState.open ? WallpaperState.contentHeight : 0
        clip: true

        // square where it meets the bar (flush, no seam), rounded only at
        // the bottom -- same opacity/color as the bar itself since this is
        // meant to read as the bar's own surface, not a separate panel.
        color: Theme.barBg
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 14
        bottomRightRadius: 14

        Behavior on height {
            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
        }

        Item {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            height: WallpaperState.headerHeight

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Wallpaper"
                color: Theme.fgSel
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: WallpaperState.folderModel.count + " image" + (WallpaperState.folderModel.count === 1 ? "" : "s")
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        GridView {
            id: grid
            anchors.top: headerRow.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            clip: true
            cellWidth: WallpaperState.cellW + WallpaperState.gap
            cellHeight: WallpaperState.cellH + WallpaperState.gap
            model: WallpaperState.folderModel

            delegate: Item {
                id: cell
                required property string filePath

                width: grid.cellWidth - WallpaperState.gap
                height: grid.cellHeight - WallpaperState.gap

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Theme.barBg
                    border.color: cellMouse.containsMouse ? Theme.accent : Theme.popupBorder
                    border.width: cellMouse.containsMouse ? 2 : 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        source: "file://" + cell.filePath
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            WallpaperState.hide();
                            Quickshell.execDetached(["feh", "--bg-fill", cell.filePath]);
                        }
                    }
                }
            }
        }

        Rectangle {
            id: scrollTrack
            visible: grid.contentHeight > grid.height
            anchors.top: grid.top
            anchors.bottom: grid.bottom
            anchors.right: parent.right
            anchors.rightMargin: 6
            width: 4
            radius: 2
            color: Theme.popupBorder

            Rectangle {
                width: parent.width
                radius: 2
                color: Theme.fgDim
                y: grid.contentHeight > 0 ? (grid.contentY / grid.contentHeight) * scrollTrack.height : 0
                height: grid.contentHeight > 0 ? Math.max(20, (grid.height / grid.contentHeight) * scrollTrack.height) : scrollTrack.height
            }
        }
    }
}
