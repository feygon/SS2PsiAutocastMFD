"""Build psi_autocast_mfd.kpf, or install it into the game.

    py build.py                  build dist/psi_autocast_mfd.kpf
    py build.py --install        also copy it into <game>\\mods (game must be closed)
    py build.py --dev ...        include dev/sq_scripts (capability probe) in the .kpf, and with
                                 --install also copy dev/*.cmd into <game>\\psi\\; never for release

Requires the psi_autocast mod (https://github.com/feygon/SS2PsiAutocast) to be installed and enabled.
"""
import argparse
import shutil
import sys
import zipfile
from pathlib import Path

GAME_DIR = Path(r"D:\EpicLibrary\SystemShock225thAnniT5DFq")
SAVE_DIR = Path.home() / "Saved Games" / "Nightdive Studios" / "System Shock 2 Remastered"
PROJECT_DIR = Path(__file__).resolve().parent
MOD_SOURCE = PROJECT_DIR / "mod"
DEV_SOURCE = PROJECT_DIR / "dev"
DIST_DIR = PROJECT_DIR / "dist"
KPF_PATH = DIST_DIR / "psi_autocast_mfd.kpf"


def build_kpf(include_dev=False):
    DIST_DIR.mkdir(exist_ok=True)
    with zipfile.ZipFile(KPF_PATH, "w", zipfile.ZIP_DEFLATED) as kpf:
        for file in sorted(MOD_SOURCE.rglob("*")):
            if file.is_file():
                kpf.write(file, file.relative_to(MOD_SOURCE).as_posix())
        if include_dev:
            for file in sorted((DEV_SOURCE / "sq_scripts").rglob("*")):
                if file.is_file():
                    kpf.write(file, file.relative_to(DEV_SOURCE).as_posix())
    print(f"built {KPF_PATH.name}" + (" (with dev tools)" if include_dev else ""))


def game_is_running():
    # The game holds its log open exclusively while it runs.
    try:
        with open(SAVE_DIR / "kexengine.log", "rb"):
            return False
    except PermissionError:
        return True
    except FileNotFoundError:
        return False


def install(include_dev):
    if include_dev:
        for item in sorted(DEV_SOURCE.glob("*.cmd")):
            shutil.copy2(item, GAME_DIR / "psi" / item.name)
            print(f"copied {item.name} to {GAME_DIR / 'psi'}")
    if game_is_running():
        print("game is running: .kpf NOT replaced (quit and re-run)")
        return 1
    shutil.copy2(KPF_PATH, GAME_DIR / "mods" / KPF_PATH.name)
    print(f"installed {KPF_PATH.name}")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--install", action="store_true", help="copy the build into the game")
    parser.add_argument("--dev", action="store_true", help="include dev tools (never for release)")
    args = parser.parse_args()
    build_kpf(include_dev=args.dev)
    return install(args.dev) if args.install else 0


if __name__ == "__main__":
    sys.exit(main())
