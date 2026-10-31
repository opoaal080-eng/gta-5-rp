#!/usr/bin/env python3
"""Integrate the optional RP file manager into open-source Muguet iOS launcher.
Does not implement RAGE MP protocol or bypass server authentication.
"""
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parent

def once(source, before, after):
    if source.count(before) != 1:
        raise ValueError(f"Expected one marker, got {source.count(before)}: {before[:70]}")
    return source.replace(before, after, 1)

def patch(source, addon):
    if "// GTA5RP_RESOURCE_ADDON_BEGIN" in source:
        return source
    source = once(source, "import Metal\n", "import Metal\nimport CryptoKit\n")
    source = once(source, "    @StateObject private var save = SaveImporter()\n",
        """    @StateObject private var save = SaveImporter()
    @StateObject private var rpStore = RPFileManager()
    @AppStorage("gta5rp.server.host") private var rpHost = ""
    @AppStorage("gta5rp.server.port") private var rpPort = "22005"
    @AppStorage("gta5rp.manifest") private var manifestAddress = ""
    @State private var pickingRP = false
""")
    source = once(source, '                Text("Muguet").font(.largeTitle.weight(.bold))',
                  '                Text("GTA5RP · Mobile Lab").font(.largeTitle.weight(.bold))')
    source = once(source, '                Section("Multiplayer") {',
                  '                Section("Muguet multiplayer (not GTA5RP)") {')
    source = once(source, '                Section("Load custom save") {', """                Section("RP · Client files") {
                    Text("Import and integrity-check resources. GTA5RP networking is NOT supported yet.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Import client_resources folder") { pickingRP = true }
                        .disabled(rpStore.busy)
                        .fileImporter(isPresented: $pickingRP, allowedContentTypes: [.folder]) { result in
                            if case .success(let url) = result { rpStore.importFolder(url) }
                        }
                    TextField("HTTPS rp-manifest.json address", text: $manifestAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Download and verify SHA-256") { rpStore.download(manifestAddress) }
                        .disabled(rpStore.busy || manifestAddress.isEmpty)
                    Text(rpStore.status).font(.caption).foregroundStyle(.secondary)
                    Text("Files: \(rpStore.count); size: \(ByteCountFormatter.string(fromByteCount: rpStore.bytes, countStyle: .file))")
                        .font(.caption)
                    Text("Resources are stored but NOT mounted into the game engine.")
                        .font(.caption).foregroundStyle(.orange)
                }
                Section("GTA5RP server (saved for future connector)") {
                    TextField("Server hostname / IP", text: $rpHost)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    TextField("Port", text: $rpPort).keyboardType(.numberPad)
                    Text("Play still runs Muguet, not GTA5RP.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Load custom save") {""")
    source = once(source, '        .onAppear { importer.scan() }',
                  '        .onAppear { importer.scan(); rpStore.refresh() }')
    return source + "\n// GTA5RP_RESOURCE_ADDON_BEGIN\n" + addon + "\n// GTA5RP_RESOURCE_ADDON_END\n"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("muguet_checkout", type=Path)
    args = parser.parse_args()
    launcher = args.muguet_checkout / "ios" / "Launcher.swift"
    if not launcher.is_file():
        parser.error(f"Missing Muguet iOS launcher: {launcher}")
    addon = (ROOT / "tools" / "RPAddon.swift").read_text("utf-8")
    addon = "\n".join(line for line in addon.splitlines() if not line.startswith("import "))
    source = launcher.read_text("utf-8")
    result = patch(source, addon)
    if result == source:
        print("Already patched")
        return
    launcher.with_name("Launcher.swift.original").write_text(source, encoding="utf-8")
    launcher.write_text(result, encoding="utf-8")
    print("Patched", launcher)

if __name__ == "__main__":
    main()
