import configparser, glob, os, subprocess, sys
from urllib.parse import parse_qsl, urlencode
import xbmcgui, xbmcplugin

DIRS = [
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
]
EXTRA = [("Software Store", ["plasma-discover"])]


def flatpak_apps():
    apps = []
    for d in DIRS:
        for path in sorted(glob.glob(os.path.join(d, "*.desktop"))):
            cp = configparser.RawConfigParser(strict=False, interpolation=None)
            cp.optionxform = str
            try:
                cp.read(path, encoding="utf-8")
                e = cp["Desktop Entry"]
            except Exception:
                continue
            if e.get("Type") != "Application" or e.get("NoDisplay", "false").lower() == "true":
                continue
            app_id = os.path.basename(path)[:-len(".desktop")]
            apps.append((e.get("Name", app_id), ["flatpak", "run", app_id]))
    return sorted(apps, key=lambda a: a[0].lower())


def main():
    handle = int(sys.argv[1])
    items = EXTRA + flatpak_apps()
    params = dict(parse_qsl(sys.argv[2][1:])) if len(sys.argv) > 2 else {}
    if "idx" in params:
        subprocess.Popen(items[int(params["idx"])][1], start_new_session=True)
        return
    for i, (name, _cmd) in enumerate(items):
        li = xbmcgui.ListItem(label=name)
        li.setArt({"icon": "DefaultProgram.png"})
        xbmcplugin.addDirectoryItem(handle, sys.argv[0] + "?" + urlencode({"idx": i}), li, False)
    xbmcplugin.endOfDirectory(handle)


main()