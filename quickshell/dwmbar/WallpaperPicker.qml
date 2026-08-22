import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import QtQuick

// Wallpaper picker, replacing the sxiv-based wallpaper-select script.
// Toggle from dwm's keybind via:
//   qs -p ~/.config/quickshell/dwmbar ipc call wallpaper toggle
PanelWindow {
    id: root

    readonly property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    readonly property int cellW: 260
    readonly property int cellH: 160
    readonly property int gap: 12
    readonly property int columns: 4

    visible: false
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // same rationale as Launcher.qml: dwm never focuses dock windows, so grab
    // X input focus ourselves once mapped, and restore it on hide. The picker
    // is the widest of our floating windows, so >1000px picks it out uniquely.
    readonly property string grabFocusCmd:
        "rd=${XDG_RUNTIME_DIR:-/tmp}; " +
        "xdotool getwindowfocus > \"$rd/qs-wallpaper-prevfocus\" 2>/dev/null; " +
        "qpid=$(pgrep -o -x qs); " +
        "for i in $(seq 40); do " +
        "for id in $(xdotool search --onlyvisible --pid \"$qpid\" 2>/dev/null); do " +
        "eval \"$(xdotool getwindowgeometry --shell \"$id\")\"; " +
        "if [ \"$WIDTH\" -gt 1000 ]; then xdotool windowfocus \"$id\"; exit 0; fi; " +
        "done; sleep 0.05; done"

    readonly property string restoreFocusCmd:
        "rd=${XDG_RUNTIME_DIR:-/tmp}; " +
        "[ -f \"$rd/qs-wallpaper-prevfocus\" ] && " +
        "xdotool windowfocus \"$(cat \"$rd/qs-wallpaper-prevfocus\")\" 2>/dev/null"

    onVisibleChanged: {
        if (visible) {
            grid.forceActiveFocus();
            Quickshell.execDetached(["sh", "-c", grabFocusCmd]);
        } else {
            Quickshell.execDetached(["sh", "-c", restoreFocusCmd]);
        }
    }

    anchors.top: true
    margins.top: Math.round((screen.height - implicitHeight) / 2)

    readonly property int rows: Math.max(1, Math.ceil(folderModel.count / columns))
    implicitWidth: columns * cellW + (columns - 1) * gap + 28
    implicitHeight: Math.min(screen.height * 0.8, headerRow.height + rows * cellH + (rows - 1) * gap + 28)

    function setShown(shown) {
        visible = shown;
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

        Item {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            height: 22

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
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.setShown(false);
                    event.accepted = true;
                }
            }

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
    }
}
