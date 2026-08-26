xrdb -merge ~/.Xresources
# restores the last wallpaper-picked pywal palette (dwm/st read these via
# their own xrdb/xresources patches at their own startup) instead of
# falling back to their compiled-in defaults every fresh login
[ -f ~/.cache/wal/colors.Xresources ] && xrdb -merge ~/.cache/wal/colors.Xresources
[ -f ~/.fehbg ] && ~/.fehbg &
picom --config ~/.config/picom.conf -b

# flatpak apps export their .desktop/icon files here; not in XDG_DATA_DIRS by
# default outside a full desktop session, so the launcher wouldn't see them
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# qt6ct's platform-theme plugin also registers under the name "qt5ct"
# (confirmed via `strings` on both libqt5ct.so and libqt6ct.so -- each
# lists both keys), so this one value themes both Qt5 and Qt6 apps: icon
# theme + the pywal-driven color scheme set up in ~/.config/qt5ct/
# qt5ct.conf and qt6ct.conf.
export QT_QPA_PLATFORMTHEME=qt6ct

# Quickshell bar: tags/layout/title/clock/volume/tray/power -- the only bar.
# dwm's own bar is fully disabled (showbar=0, showsystray=0 in config.h) but
# still reserves the same barheight strip of screen space for it.
# NotificationStore.qml owns org.freedesktop.Notifications (dunst retired).
#
# Run as a systemd --user unit instead of a bare background job: systemd
# restarts it on crash, and (unlike a plain `qs &`) `stop` reliably kills it
# via its cgroup even if the process is wedged -- a stale `qs &` process
# whose X11 connection died would otherwise linger holding the single-
# instance lock, so the next session's bar would silently fail to appear.
systemctl --user import-environment DISPLAY XAUTHORITY XDG_DATA_DIRS QT_QPA_PLATFORMTHEME
systemctl --user daemon-reload
systemctl --user restart quickshell-dwmbar.service

# polkit auth agent -- without one, anything needing elevated privileges via
# polkit (mounting drives, network config, etc.) fails with no prompt at all
systemctl --user restart polkit-gnome.service

dwm

systemctl --user stop quickshell-dwmbar.service
systemctl --user stop polkit-gnome.service
