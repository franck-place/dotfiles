import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import QtQuick

// Wallpaper picker, replacing the sxiv-based wallpaper-select script.
// Toggle from dwm's keybind via:
//   qs ipc -p ~/.config/quickshell/dwmbar call wallpaper toggle
// Anchored to the bar like the other dropdowns (power/volume/notifications/
// calendar) so it visually drops down out of it instead of floating as a
// separate centered window; outside-click dismissal comes from ClickCatcher
// via PopupGuard, same as those.
PopupWindow {
    id: root

    required property var bar

    readonly property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    readonly property int cellW: 260
    readonly property int cellH: 160
    readonly property int gap: 12
    readonly property int columns: 4
    readonly property int headerHeight: 22

    // GridView lays cells out on a uniform (cellW+gap)/(cellH+gap) pitch,
    // including a trailing gap after the last column/row -- so the view
    // needs a full pitch per column/row, not (n-1) gaps, to actually fit
    // `columns` across without wrapping early.
    readonly property int cellPitchW: cellW + gap
    readonly property int cellPitchH: cellH + gap
    readonly property int maxVisibleRows: 3
    readonly property int rows: Math.max(1, Math.ceil(folderModel.count / columns))
    readonly property int visibleRows: Math.min(rows, maxVisibleRows)
    readonly property int fullContentHeight: headerHeight + 38 + visibleRows * cellPitchH

    anchor.window: root.bar
    anchor.rect.x: Math.round((root.bar.width - implicitWidth) / 2)
    anchor.rect.y: Theme.barHeight

    visible: false
    color: "transparent"

    implicitWidth: columns * cellPitchW + 28
    // dropdown motion: grows open from the bar instead of just popping in.
    implicitHeight: visible ? fullContentHeight : 0

    Behavior on implicitHeight {
        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
    }

    function setShown(shown) {
        if (shown)
            PopupGuard.claim(root);
        root.visible = shown;
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + root.wallpapersDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    IpcHandler {
        target: "wallpaper"

        function toggle() {
            root.setShown(!root.visible);
        }

        function show() {
            root.setShown(true);
        }

        function hide() {
            root.setShown(false);
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 14
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: 1
        clip: true

        Item {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            height: root.headerHeight

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
                text: folderModel.count + " image" + (folderModel.count === 1 ? "" : "s")
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
            cellWidth: root.cellW + root.gap
            cellHeight: root.cellH + root.gap
            model: folderModel

            delegate: Item {
                id: cell
                required property string filePath

                width: grid.cellWidth - root.gap
                height: grid.cellHeight - root.gap

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
                            root.setShown(false);
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
