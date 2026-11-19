#!/usr/bin/env python3
"""
Patch smb-lib.c (driver charger PMI8998 / qpnp-smb2) agar batas arus masuk USB
bisa dipaksa ke mode HC (arus bebas) lewat parameter modul otg_chg_icl_ua.

- otg_chg_icl_ua = 0  -> perilaku asli (tidak ada perubahan)
- otg_chg_icl_ua > 0  -> setiap kali driver memasang batas arus (>= 25 mA),
                         nilainya diganti dengan otg_chg_icl_ua (maks 3 A) dan
                         jalur "port USB biasa 500 mA" (set_sdp_current) dilewati.
Saat ponsel sedang mengeluarkan daya OTG, driver memasang batas 0 (suspend);
nilai itu TIDAK diubah, jadi patch ini tidak aktif ketika OTG biasa menyala.
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
path = root / "drivers/power/supply/qcom/smb-lib.c"
if not path.exists():
    sys.exit(f"GAGAL: {path} tidak ditemukan")

src = path.read_text()
if "otg_chg_icl_ua" in src:
    print("smb-lib.c sudah dipatch, dilewati.")
    sys.exit(0)

# 1) Parameter modul, diletakkan setelah #include terakhir.
includes = list(re.finditer(r"^#include[^\n]*\n", src, re.M))
if not includes:
    sys.exit("GAGAL: tidak menemukan #include di smb-lib.c")
pos = includes[-1].end()
param = (
    "#include <linux/moduleparam.h>\n"
    "\n/* OTG sambil mengisi: batas arus masuk paksa dalam uA, 0 = nonaktif */\n"
    "static int otg_chg_icl_ua;\n"
    "module_param(otg_chg_icl_ua, int, 0644);\n"
    'MODULE_PARM_DESC(otg_chg_icl_ua, "Force HC-mode USB ICL in uA (0 = off)");\n'
)
src = src[:pos] + param + src[pos:]

# 2) Fungsi smblib_set_icl_current.
fm = re.search(r"int\s+smblib_set_icl_current\s*\(\s*struct\s+smb_charger\s*\*\s*chg\s*,\s*int\s+icl_ua\s*\)\s*\{", src)
if not fm:
    sys.exit("GAGAL: fungsi smblib_set_icl_current tidak ditemukan")
start = fm.end()
end = src.find("\n}\n", start)
if end < 0:
    sys.exit("GAGAL: akhir fungsi smblib_set_icl_current tidak ditemukan")
body = src[start:end]

print("===== smblib_set_icl_current (asli) =====")
print(body)
print("=========================================")

# 2a) Lewati jalur SDP (port USB biasa) saat parameter aktif.
body, n = re.subn(r"POWER_SUPPLY_TYPE_USB\s*\)", "POWER_SUPPLY_TYPE_USB && !otg_chg_icl_ua)", body)
if n == 0:
    sys.exit("GAGAL: pola 'POWER_SUPPLY_TYPE_USB)' tidak ditemukan di fungsi; kirim log ini.")
print(f"Kondisi SDP yang diubah: {n}")

# 2b) Sisipkan pengganti nilai setelah deklarasi variabel di awal fungsi.
lines = body.split("\n")
decl = re.compile(r"^\s*(?:const\s+)?(?:int|bool|u8|u16|u32|unsigned\s+int|union\s+\w+|struct\s+\w+)\s*\*?\s*\w+[^;()]*;\s*$")
idx = 0
for i, line in enumerate(lines):
    s = line.strip()
    if s == "" or s.startswith("//") or s.startswith("/*") or s.startswith("*"):
        continue
    if decl.match(line):
        idx = i + 1
        continue
    break
hook = [
    "",
    "\tif (otg_chg_icl_ua > 0 && icl_ua > 25000 && icl_ua != INT_MAX)",
    "\t\ticl_ua = otg_chg_icl_ua > 3000000 ? 3000000 : otg_chg_icl_ua;",
    "",
]
lines[idx:idx] = hook
body = "\n".join(lines)

src = src[:start] + body + src[end:]
path.write_text(src)

print("===== smblib_set_icl_current (setelah patch) =====")
print(body)
print("==================================================")
print("Patch berhasil.")
