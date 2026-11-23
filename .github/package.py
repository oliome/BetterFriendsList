"""Build an install ZIP with a single BetterFriendsList folder."""
from pathlib import Path
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
files = ["BetterFriendsList.toc", "BetterFriendsList.lua", "Options.lua"]
destination = Path(sys.argv[1])
destination.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(root / name, "BetterFriendsList/" + name)
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == {"BetterFriendsList/" + name for name in files}
print(destination)
