from pathlib import Path
import hashlib, shutil

wrap = Path(r'rtl/fx68k/fx68k_m68kcpu_wrap.sv')
bak = Path(r'rtl/fx68k/fx68k_m68kcpu_wrap.sv.pre_vpa_enphi2.bak')
alt1 = Path(r'rtl/fx68k/fx68k_m68kcpu_wrap.sv.pre_as_stretch_alt1.bak')

raw = wrap.read_bytes()
print('wrap MD5 before:', hashlib.md5(raw).hexdigest().upper())
print('alt1 MD5:', hashlib.md5(alt1.read_bytes()).hexdigest().upper())
ts = b'`timescale'
print('timescale present:', ts in raw)
print('CRLF:', b'\r\n' in raw)
assert hashlib.md5(raw).hexdigest().upper() == 'E98AAB3EBAAF748BD4ACEB926C250951'
assert ts in raw

if not bak.exists():
    shutil.copy2(wrap, bak)
print('bak MD5:', hashlib.md5(bak.read_bytes()).hexdigest().upper())

text = raw.decode('utf-8')
nl = '\r\n' if '\r\n' in text else '\n'

old_hdr = (
    '// ALT1: BR/BGACK flopped on enPhi2 (vs VCLK C291/F85A baseline)' + nl +
    '// - KEEP: *n pass-through except BRn/BGACKn=br_d/bgack_d; BG=BGn; RW_z=eRWn&ASn; strobe_z=ASn'
)
new_hdr = (
    '// ALT1+VPA: BR/BGACK/VPA flopped on enPhi2 (vs ALT1 E98AAB3E)' + nl +
    '// - KEEP: *n pass-through except BRn/BGACKn=br_d/bgack_d, VPAn=vpa_d; BG=BGn; RW_z=eRWn&ASn; strobe_z=ASn'
)
assert old_hdr in text, 'header block not found'
text = text.replace(old_hdr, new_hdr, 1)

old_block = (
    '\t// ALT1: BR/BGACK enPhi2-register (stable at next enPhi1); ONE VARIABLE vs VCLK baseline' + nl +
    '\treg br_d, bgack_d;' + nl +
    '\talways @(posedge MCLK) begin' + nl +
    '\t\tif (fx_reset) begin' + nl +
    "\t\t\tbr_d <= 1'b1;" + nl +
    "\t\t\tbgack_d <= 1'b1;" + nl +
    '\t\tend else if (enPhi2) begin' + nl +
    '\t\t\tbr_d <= BR;' + nl +
    '\t\t\tbgack_d <= BGACK;' + nl +
    '\t\tend' + nl +
    '\tend'
)
new_block = (
    '\t// ALT1+VPA: BR/BGACK/VPA enPhi2-register (stable at next enPhi1); ONE VARIABLE vs ALT1' + nl +
    '\treg br_d, bgack_d, vpa_d;' + nl +
    '\talways @(posedge MCLK) begin' + nl +
    '\t\tif (fx_reset) begin' + nl +
    "\t\t\tbr_d <= 1'b1;" + nl +
    "\t\t\tbgack_d <= 1'b1;" + nl +
    "\t\t\tvpa_d <= 1'b1;" + nl +
    '\t\tend else if (enPhi2) begin' + nl +
    '\t\t\tbr_d <= BR;' + nl +
    '\t\t\tbgack_d <= BGACK;' + nl +
    '\t\t\tvpa_d <= VPA;' + nl +
    '\t\tend' + nl +
    '\tend'
)
assert old_block in text, 'ALT1 reg block not found'
text = text.replace(old_block, new_block, 1)

old_vpa = '\t\t.VPAn(VPA),'
new_vpa = '\t\t.VPAn(vpa_d),'
assert old_vpa in text, 'VPAn(VPA) not found'
text = text.replace(old_vpa, new_vpa, 1)

out = text.encode('utf-8')
assert ts in out, 'timescale lost!'
assert b'`timescale 1ns / 1ns' in out
wrap.write_bytes(out)
print('wrap MD5 after:', hashlib.md5(out).hexdigest().upper())
print('timescale intact: True')
print('VPAn(vpa_d):', b'.VPAn(vpa_d)' in out)
print('vpa_d reg:', b'reg br_d, bgack_d, vpa_d' in out)
