import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    NotificationToasts {}

    ClickCatcher {}

    Launcher {}

    SettingsWindow {}
}
