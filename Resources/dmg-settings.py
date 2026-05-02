"""dmgbuild settings — produces D4Mac.dmg without using AppleScript/Finder.

Invoke from build.sh as:
    dmgbuild -s Resources/dmg-settings.py \
             -D app=$APP -D background=$BG \
             "D4Mac" $DMG_PATH

`defines` (-D) supplied at runtime: app, background.
"""

import os.path

# Resolved by dmgbuild from -D flags:
app = defines.get("app")  # type: ignore[name-defined]
background = defines.get("background")  # type: ignore[name-defined]

format = "UDZO"  # zlib-compressed, the standard for distribution
compression_level = 9
filesystem = "APFS"

# Explicit size with headroom — auto-sizing leaves no room for .DS_Store
# next to the 2 GB .app and dmgbuild errors with ENOSPC.
size = "2.5G"

files = [app]
symlinks = {"Applications": "/Applications"}

icon_locations = {
    os.path.basename(app): (165, 200),
    "Applications": (495, 200),
}

# Window appearance
window_rect = ((300, 200), (660, 400))
default_view = "icon-view"
show_icon_preview = False
show_pathbar = False
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_sidebar = False
sidebar_width = 0

# Icon view styling
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 13
icon_size = 96
include_icon_view_settings = "auto"
include_list_view_settings = "auto"
