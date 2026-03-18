# Affinity on Linux — Universal Installer

Automated installer for the Affinity suite (Photo, Designer, Publisher) on Linux via Wine 10.17+.

Works on Ubuntu, Debian, Linux Mint, Fedora, Arch, Manjaro, openSUSE, Pop!_OS, Zorin, and all their derivatives.

---

## What This Does

Affinity apps require Windows Runtime (WinRT) APIs that only became available in Wine 10.17. Most Linux distributions ship with an older version of Wine by default, which causes the Affinity installer to crash silently.

This script handles the entire setup automatically:

- Detects your Linux distribution and package manager
- Upgrades Wine to 10.17+ from the official WineHQ repository
- Creates an isolated Wine prefix for Affinity
- Installs the required .NET and Visual C++ runtime components
- Runs the Affinity installer
- Downloads and places the WinRT helper files (`Windows.winmd` and `wintypes.dll`)
- Configures the necessary DLL override
- Creates a desktop launcher with automatic health checks on every start
- Optionally installs AffinityPluginLoader for improved stability

---

## Requirements

- A 64-bit x86 Linux system
- At least 10 GB of free disk space
- An active internet connection
- An Affinity installer `.exe` downloaded to your machine

Download the Affinity installer from one of these sources:

- [Affinity by Canva (latest)](https://affinity.studio/download)
- [Affinity V2 (legacy)](https://affinity.serif.com/v2/)
- [Archived builds](https://archive.org/details/affinity_20251030)

---

## Supported Distributions

| Family   | Distributions                                              |
|----------|------------------------------------------------------------|
| Debian   | Ubuntu, Debian, Linux Mint, Pop!_OS, Zorin, elementary OS  |
| Fedora   | Fedora, Nobara, RHEL, Rocky Linux, AlmaLinux               |
| Arch     | Arch Linux, Manjaro, EndeavourOS, Garuda, CachyOS           |
| openSUSE | openSUSE Tumbleweed, Leap                                  |

If your distribution is not listed, the script will attempt to use Debian-style commands. If it fails, install Wine 10.17+ manually from [WineHQ](https://dl.winehq.org) and re-run the script.

---

## Installation

### Step 1 — Download the installer

```bash
curl -L -o affinity_install.sh https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/affinity_install.sh
chmod +x affinity_install.sh
```

Or clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
chmod +x affinity_install.sh
```

### Step 2 — Place your Affinity installer

Put your downloaded `Affinity.exe` (or `Affinity x64.exe`) in your `Downloads` folder.  
The script will find it automatically. If it does not, you will be prompted to enter the path.

### Step 3 — Run the installer

```bash
bash affinity_install.sh
```

The script will guide you through each step with clear progress messages.  
Installation takes 20 to 40 minutes, mostly due to the .NET Framework download.

---

## Usage

### Full installation (default)

```bash
bash affinity_install.sh
```

### Repair an existing installation

Use this if Affinity stopped launching after a system update, or if any helper files went missing:

```bash
bash affinity_install.sh --repair
```

The repair mode checks each component individually and fixes only what is broken without reinstalling everything.

### Uninstall

```bash
bash affinity_install.sh --uninstall
```

This removes the Wine prefix, all Affinity data inside it, and the desktop launcher.

### Custom Wine prefix location

By default the installer uses `~/.affinity`. To use a different location:

```bash
WINEPREFIX=/path/to/your/prefix bash affinity_install.sh
```

---

## After Installation

Affinity will appear in your application menu under the Graphics category.

A desktop shortcut is also created if you have a `~/Desktop` folder.

To launch from the terminal:

```bash
bash ~/.local/bin/affinity_launch.sh
```

The launcher script runs a health check before every start. If any file is missing (for example after a system update), it automatically re-downloads and restores it before launching Affinity.

---

## What Gets Installed

| Component          | Purpose                                               |
|--------------------|-------------------------------------------------------|
| Wine 10.17+        | Windows compatibility layer                           |
| winetricks         | Wine component installer                              |
| vcrun2022          | Visual C++ 2022 runtime (required by Affinity)        |
| dotnet48           | .NET Framework 4.8 (required by Affinity installer)   |
| corefonts          | Microsoft core fonts                                  |
| Windows.winmd      | WinRT API metadata                                    |
| wintypes.dll       | WinRT shim DLL by ElementalWarrior                    |

Everything is installed into an isolated Wine prefix at `~/.affinity`.  
Your system is not modified beyond the Wine package installation.

---

## AffinityPluginLoader

During installation you will be offered the option to install [AffinityPluginLoader](https://github.com/noahc3/AffinityPluginLoader) by Noah C3. This is a community patch that:

- Fixes settings and preferences not saving on Linux
- Improves runtime stability under Wine
- Bypasses the Canva sign-in dialog on startup

It is not required, but recommended for a better experience. You can install it later by re-running the installer or following the instructions in the AffinityPluginLoader repository.

---

## Troubleshooting

### Affinity installer crashes immediately

**Cause:** Wine is too old. The Affinity installer requires WinRT APIs that are only available in Wine 10.17 or newer.

**Fix:** Run the installer script. It will upgrade Wine automatically.  
If you prefer to upgrade manually, see the [WineHQ installation guide](https://wiki.winehq.org/Download).

Verify your Wine version:

```bash
wine --version
```

It should return `wine-10.17` or higher.

---

### dotnet48 takes a very long time or appears frozen

This is normal. The .NET 4.8 installation is large and generates a lot of Wine debug output. It can take 15 to 30 minutes. Leave the terminal open.

If it is still running after 35 minutes and nothing has changed, you can kill it:

```bash
pkill -f winetricks
pkill -f wineserver
pkill -f wine
```

Then re-run the installer. It will skip dotnet48 if already partially installed and continue with the remaining steps. The dotnet48 timeout in the script is set to 30 minutes.

---

### Wine configuration window (winecfg) did not appear

It may have opened behind another window. Check your taskbar.

If it is not there, open a second terminal and run:

```bash
WINEPREFIX="$HOME/.affinity" winecfg
```

In the Libraries tab, add `wintypes`, edit it, and set it to Native (Windows).

---

### Affinity launches but shows a blank screen or crashes

Try installing the Vulkan renderer:

```bash
WINEPREFIX="$HOME/.affinity" winetricks renderer=vulkan
WINEPREFIX="$HOME/.affinity" winetricks dxvk
```

---

### Fonts appear pixelated or corrupted

```bash
WINEPREFIX="$HOME/.affinity" winetricks tahoma
```

---

### Preferences and settings do not save between sessions

Install [AffinityPluginLoader](https://github.com/noahc3/AffinityPluginLoader). This is a known limitation of Affinity under Wine and the plugin loader contains a specific fix for it.

---

### "Failed to add WineHQ repository" on Linux Mint

Linux Mint uses Ubuntu codenames internally. The installer maps them automatically. If it fails:

Find your Ubuntu base:

```bash
cat /etc/upstream-release/lsb-release
```

Then add the WineHQ repository manually using that codename following the [WineHQ Ubuntu guide](https://wiki.winehq.org/Ubuntu).

---

### Repair mode

If Affinity was working and stopped after a system update:

```bash
bash affinity_install.sh --repair
```

This checks and restores each component without touching your Affinity installation or settings.

---

## How It Works

Affinity apps use the Windows Runtime (WinRT) API layer for parts of their installer and application UI. Before Wine 10.17, WinRT metadata loading was not implemented, which caused the Affinity installer to crash with error `0xe0434352` (a CLR/WinRT exception).

Wine 10.17 added support for loading WinRT metadata files (`.winmd`). Two additional files are required:

- `Windows.winmd` from the [windows-rs](https://github.com/microsoft/windows-rs) project provides the actual API type definitions
- `wintypes.dll` by [ElementalWarrior](https://github.com/ElementalWarrior/wine-wintypes.dll-for-affinity) is a shim DLL that bridges WinRT calls to Wine's implementation

With these files in place and the `wintypes` DLL override set to Native, Affinity installs and runs correctly.

---

## File Structure

```
affinity_install.sh          Main installer script
~/.affinity/                 Wine prefix (created during install)
~/.local/bin/affinity_launch.sh   Health-check launcher
~/.local/share/applications/Affinity.desktop   App menu entry
~/Desktop/Affinity.desktop   Desktop shortcut
~/affinity_install.log       Installation log
```

---

## Credits

- [ElementalWarrior](https://github.com/ElementalWarrior) — creator of wine-wintypes.dll-for-affinity
- [Wanesty](https://codeberg.org/wanesty) — discovered the Wine 10.17 solution
- [WineHQ Team](https://www.winehq.org) — added WinRT metadata support in Wine
- [Noah C3](https://github.com/noahc3) — creator of AffinityPluginLoader and WineFix
- [seapear/AffinityOnLinux](https://github.com/seapear/AffinityOnLinux) — documentation and community guide
- [Microsoft](https://github.com/microsoft/windows-rs) — provider of Windows.winmd metadata

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Related Projects

- [AffinityOnLinux guide](https://github.com/seapear/AffinityOnLinux) — comprehensive manual guide
- [AffinityPluginLoader](https://github.com/noahc3/AffinityPluginLoader) — stability patches
- [affinity.liz.pet](https://affinity.liz.pet) — Wanesty's original guide
- [AffinityOnLinux community](https://join.affinityonlinux.com) — Discord server
