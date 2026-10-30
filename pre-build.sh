#!/usr/bin/env bash
# Inject the Simplified Chinese WebUI dictionary into nilabsent/padavan-ng.
set -euo pipefail

BUILDER_DIR="$(pwd)"
SOURCE_DIR="$BUILDER_DIR/padavan-ng"
DICT_SRC="$BUILDER_DIR/CN.dict"
DICT_DST="$SOURCE_DIR/trunk/user/www/dict/CN.dict"

if [ ! -f "$DICT_SRC" ]; then
    echo "CN.dict not found in the builder repository root" >&2
    exit 1
fi

install -m 0644 "$DICT_SRC" "$DICT_DST"

python3 - <<'PY'
from pathlib import Path

root = Path.cwd()
makefile = root / "padavan-ng/trunk/user/www/Makefile"
text = makefile.read_text(encoding="utf-8")
needle = "ifeq ($(CONFIG_FIRMWARE_INCLUDE_LANG_SV),y)"
block = """ifeq ($(CONFIG_FIRMWARE_INCLUDE_LANG_CN),y)
\techo \"LANG_CN=简体中文\" >> $(ROMFS_DIR)/www/EN.header
\tcp dict/CN.dict $(ROMFS_DIR)/www
endif

"""
if "CONFIG_FIRMWARE_INCLUDE_LANG_CN" not in text:
    if needle not in text:
        raise SystemExit("Could not find the language insertion point in www/Makefile")
    text = text.replace(needle, block + needle, 1)
    makefile.write_text(text, encoding="utf-8", newline="\n")

creator = root / "padavan-ng/trunk/user/www/create_new_dict.sh"
text = creator.read_text(encoding="utf-8")
old = "for l in BR DA EN ES FR PL SV CZ DE EN FI NO RU UK; do"
new = "for l in BR DA EN ES FR PL SV CZ DE EN FI NO RU UK CN; do"
if old in text:
    creator.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")

# Hide the VPN Server / VPN Client entries in the WebUI sidebar.
# The renderer skips any menuL1 item whose title is empty (same trick
# the firmware itself uses in AP mode), so blanking title+link is enough.
state = root / "padavan-ng/trunk/user/www/n56u_ribbon_fixed/state.js"
text = state.read_text(encoding="utf-8")

marker = "// hide VPN/USB sidebar menus (patched)"
if marker not in text:
    anchor = 'menuL1_icon = new Array("", "icon-home", "icon-hdd", "icon-retweet", "icon-globe", "icon-tasks", "icon-random", "icon-wrench");'
    if anchor not in text:
        raise SystemExit("Could not find the menu anchor in state.js")
    patch = (anchor + "\n\n" + marker + "\n"
        + 'menuL1_link[2] = "";  //remove USB Applications (AiDisk)\n'
        + 'menuL1_title[2] = "";\n'
        + 'menuL1_link[3] = "";  //remove VPN svr\n'
        + 'menuL1_title[3] = "";\n'
        + 'menuL1_link[4] = "";  //remove VPN cli\n'
        + 'menuL1_title[4] = "";\n')
    text = text.replace(anchor, patch, 1)

# Hide all USB Applications sub-tabs: General Settings (index 1),
# USB modem (index 4) and USB printer (index 5).
usb_marker = "// hide USB application tabs (patched)"
if usb_marker not in text:
    usb_anchor = 'tablink[5] = new Array("", "Advanced_AiDisk_others.asp", "Advanced_AiDisk_samba.asp", "Advanced_AiDisk_ftp.asp", "Advanced_Modem_others.asp", "Advanced_Printer_others.asp");'
    if usb_anchor not in text:
        raise SystemExit("Could not find the USB tablink anchor in state.js")
    usb_patch = (usb_anchor + "\n\n" + usb_marker + "\n"
        + 'tabtitle[5][1] = "";  //remove General Settings\n'
        + 'tablink[5][1] = "";\n'
        + 'tabtitle[5][4] = "";  //remove USB modem\n'
        + 'tablink[5][4] = "";\n'
        + 'tabtitle[5][5] = "";  //remove USB printer\n'
        + 'tablink[5][5] = "";\n')
    text = text.replace(usb_anchor, usb_patch, 1)

# Trim the git commit suffix from the version shown in the top bar,
# e.g. 3.4.4.0-105_007433a -> 3.4.4.0-105
ver_old = '''showtext($("firmver"), '<% nvram_get_x("",  "firmver_sub"); %>');'''
ver_new = '''showtext($("firmver"), '<% nvram_get_x("",  "firmver_sub"); %>'.split('_')[0]);'''
if ver_old in text:
    text = text.replace(ver_old, ver_new, 1)
elif ver_new not in text:
    raise SystemExit("Could not find the firmware version line in state.js")

# Remove the page footer (copyright / Highcharts / Freepik / Non-Commercial).
foot_old = '\t$("footer").innerHTML = footer_code;'
foot_new = '\t$("footer").innerHTML = ""; // footer hidden (patched)'
if foot_old in text:
    text = text.replace(foot_old, foot_new, 1)
elif foot_new not in text:
    raise SystemExit("Could not find the footer line in state.js")

state.write_text(text, encoding="utf-8", newline="\n")

# Disable USB 3.0 by default (reduces 2.4GHz Wi-Fi interference on MI-R3G).
# Users can still re-enable it in the WebUI; this only flips the nvram default.
defaults = root / "padavan-ng/trunk/user/shared/defaults.c"
text = defaults.read_text(encoding="utf-8")
usb3_old = '{ "usb3_disable", "0" },'
usb3_new = '{ "usb3_disable", "1" },'
if usb3_old in text:
    text = text.replace(usb3_old, usb3_new, 1)
    defaults.write_text(text, encoding="utf-8", newline="\n")
elif usb3_new not in text:
    raise SystemExit("Could not find the usb3_disable default in defaults.c")
PY

# Ensure the device config enables the Chinese resource even if it was not edited manually.
DEVICE_CONFIG="$BUILDER_DIR/configs.build/mi-r3g.config"
if [ -f "$DEVICE_CONFIG" ] && ! grep -q '^CONFIG_FIRMWARE_INCLUDE_LANG_CN=y$' "$DEVICE_CONFIG"; then
    printf '\n# Simplified Chinese WebUI\nCONFIG_FIRMWARE_INCLUDE_LANG_CN=y\n' >> "$DEVICE_CONFIG"
fi

echo "Simplified Chinese WebUI support injected"
