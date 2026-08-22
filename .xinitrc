xrdb -merge ~/.Xresources
[ -f ~/.fehbg ] && ~/.fehbg &
picom --config ~/.config/picom.conf -b

# flatpak apps export their .desktop/icon files here; not in XDG_DATA_DIRS by
# default outside a full desktop session, so the launcher wouldn't see them
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

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
systemctl --user import-environment DISPLAY XAUTHORITY XDG_DATA_DIRS
systemctl --user daemon-reload
systemctl --user restart quickshell-dwmbar.service

dwm

systemctl --user stop quickshell-dwmbar.service
