pragma Singleton
import Quickshell
import Qt.labs.folderlistmodel
import QtQuick

// Shared state + sizing math for the wallpaper picker (WallpaperPicker.qml),
// a small window anchored flush under the bar in just its own column. A
// singleton so the picker and ClickCatcher.qml can both read the same
// numbers without duplicating the layout math.
Singleton {
    id: root

    property bool open: false

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

    readonly property int panelWidth: columns * cellPitchW + 28
    readonly property int contentHeight: headerHeight + 38 + visibleRows * cellPitchH

    property alias folderModel: folderModel

    function toggle() { root.open = !root.open; }
    function show() { root.open = true; }
    function hide() { root.open = false; }

    FolderListModel {
        id: folderModel
        folder: "file://" + root.wallpapersDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png"]
        showDirs: false
        sortField: FolderListModel.Name
    }
}
