pragma Singleton
import Quickshell
import QtQuick

// rust/espresso palette, matching ~/.config/dwm/config.h
Singleton {
    readonly property int barHeight: 30

    readonly property color barBg: "#1c1714"
    readonly property color fg: "#c9b79c"
    readonly property color fgSel: "#f2e8d5"
    readonly property color fgDim: "#8a7460"
    readonly property color accent: "#b5651d"
    readonly property color urgent: "#d1495b"
    readonly property color hover: "#33c9b79c"

    readonly property string fontFamily: "JetBrains Mono"
    readonly property int fontSize: 13

    readonly property string iconFont: "Symbols Nerd Font Mono"
    readonly property int iconSize: 15

    readonly property color popupBg: "#241d17"
    readonly property color popupBorder: "#3dc9b79c"
}
