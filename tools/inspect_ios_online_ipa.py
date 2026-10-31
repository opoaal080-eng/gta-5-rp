#!/usr/bin/env python3
"""Read-only detection of GTA V iOS online IPA network markers. No game data extracted."""
import argparse
import json
import plistlib
import zipfile

MARKERS = {
    "p2p_protocol": b"gtavmp-p2p-1|",
    "bonjour_service": b"_gtavmp._udp",
    "dht_discovery": b"BitTorrent's DHT",
    "online_session": b"GTA Online",
    "rage_mp_marker": b"RAGE MP",
}
def inspect(path):
    with zipfile.ZipFile(path) as ipa:
        names = ipa.namelist()
        plist_name = next(n for n in names if n.endswith(".app/Info.plist"))
        prefix = plist_name[:-len("Info.plist")]
        info = plistlib.loads(ipa.read(plist_name))
        modules = [n for n in names if n.startswith(prefix) and (
            n.endswith(".dylib") or n == prefix + info["CFBundleExecutable"])]
        found = {}
        for marker, value in MARKERS.items():
            found[marker] = [n[len(prefix):] for n in modules if value in ipa.read(n)]
        return {
            "bundle_id": info.get("CFBundleIdentifier"),
            "executable": info.get("CFBundleExecutable"),
            "min_ios": info.get("MinimumOSVersion"),
            "bonjour": info.get("NSBonjourServices", []),
            "modules": [n[len(prefix):] for n in modules],
            "markers": found,
            "warning": "These are static string markers, not tested protocol interoperability."
        }
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa")
    args = parser.parse_args()
    print(json.dumps(inspect(args.ipa), indent=2, ensure_ascii=False))
