import re
from pathlib import Path

import olefile

SRC = Path(r"C:\Users\sokol\Desktop\video presentation\Orbita.vproj")
OUT = Path(r"D:\Projects\messanger\messenger\presentation\analysis\media")
OUT.mkdir(parents=True, exist_ok=True)

MAGIC = {
    b"\x89PNG\r\n\x1a\n": "png",
    b"\xff\xd8\xff": "jpg",
    b"GIF8": "gif",
    b"RIFF": "riff",
    b"OggS": "ogg",
    b"\x1aE\xdf\xa3": "webm",
    b"ID3": "mp3",
}

ole = olefile.OleFileIO(str(SRC))
for entry in ole.listdir():
    name = "/".join(entry)
    if not name.endswith("Stream"):
        continue
    data = ole.openstream(entry).read()
    kind = "bin"
    for magic, ext in MAGIC.items():
        if data.startswith(magic):
            kind = ext
            break
    if data[:4] == b"RIFF" and data[8:12] == b"WAVE":
        kind = "wav"
    out = OUT / (name.replace("/", "_") + f".{kind}")
    out.write_bytes(data)
    print(f"{kind:5s} {len(data):9d}  {name}")

print("\n--- strings from root stream and settings ---")
def strings(data, minlen=4):
    res = []
    for enc in ("utf-16-le", "utf-8"):
        try:
            txt = data.decode(enc, errors="ignore")
        except Exception:
            continue
        res += re.findall(rf"[ -~А-Яа-яЁё]{{{minlen},}}", txt)
    return res

for target in ("\x05Byfdu3c5Cehdu40cD4b5tmhkAh", "ObjectLibrary/\x050h4uz0ntOh4femkz0ipj5r4zMa"):
    data = ole.openstream(target.split("/")).read()
    print(f"=== {target!r} {len(data)}")
    for s in strings(data)[:120]:
        print("   ", s)

print("\n=== ObjectSettings2/3 strings ===")
for entry in ole.listdir():
    name = "/".join(entry)
    if name.startswith("ObjectSettings2") or name.startswith("ObjectSettings3"):
        data = ole.openstream(entry).read()
        print(f"--- {name!r} {len(data)}")
        for s in strings(data)[:40]:
            print("   ", s)
ole.close()
