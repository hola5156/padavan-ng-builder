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
PY

# Ensure the device config enables the Chinese resource even if it was not edited manually.
DEVICE_CONFIG="$BUILDER_DIR/configs.build/mi-r3g.config"
if [ -f "$DEVICE_CONFIG" ] && ! grep -q '^CONFIG_FIRMWARE_INCLUDE_LANG_CN=y$' "$DEVICE_CONFIG"; then
    printf '\n# Simplified Chinese WebUI\nCONFIG_FIRMWARE_INCLUDE_LANG_CN=y\n' >> "$DEVICE_CONFIG"
fi

echo "Simplified Chinese WebUI support injected"
