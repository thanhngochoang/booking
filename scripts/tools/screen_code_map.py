"""Old flat screen codes (S01–S70) → use-case codes Sxx.yy (user decision 2026-10-02).

Run from the repo root: python3 scripts/tools/screen_code_map.py <files...>
Rewrites old codes in place; ranges become the use cases or screens they cover.
"""
import re
import sys

MAP = {
    # S01 Vào app & tài khoản
    'S66': 'S01.01', 'S67': 'S01.02', 'S28': 'S01.03', 'S41': 'S01.04', 'S29': 'S01.05',
    # S02 Khám phá & tìm thợ
    'S01': 'S02.01', 'S02': 'S02.02', 'S13': 'S02.03', 'S35': 'S02.04', 'S36': 'S02.05', 'S04': 'S02.06',
    # S03 Xem hồ sơ nhiếp ảnh gia
    'S03': 'S03.01', 'S37': 'S03.02',
    # S04 Đặt lịch
    'S05': 'S04.01', 'S06': 'S04.02', 'S07': 'S04.03', 'S08': 'S04.04', 'S33': 'S04.05',
    # S05 Theo dõi buổi chụp (khách)
    'S14': 'S05.01', 'S09': 'S05.02', 'S10': 'S05.03', 'S32': 'S05.04', 'S12': 'S05.05',
    # S06 Nhận việc (nhiếp ảnh gia)
    'S19': 'S06.01', 'S22': 'S06.02', 'S23': 'S06.03', 'S20': 'S06.04', 'S43': 'S06.05', 'S44': 'S06.06',
    # S07 Hội thoại
    'S11': 'S07.01', 'S68': 'S07.02',
    # S08 Thiết lập hồ sơ nhiếp ảnh gia
    'S24': 'S08.01', 'S38': 'S08.02', 'S39': 'S08.03', 'S40': 'S08.04', 'S34': 'S08.05',
    # S09 Hồ sơ cá nhân & cài đặt
    'S30': 'S09.01', 'S31': 'S09.02', 'S42': 'S09.03',
    # S10 Đăng bài
    'S21': 'S10.01',
    # S11 Tham gia sự kiện
    'S15': 'S11.01', 'S16': 'S11.02', 'S17': 'S11.03', 'S18': 'S11.04', 'S45': 'S11.05', 'S46': 'S11.06',
    # S12 Tổ chức sự kiện
    'S25': 'S12.01', 'S26': 'S12.02', 'S27': 'S12.03',
    # S13 Chụp ngay (khách)
    'S47': 'S13.01', 'S69': 'S13.02', 'S48': 'S13.03', 'S70': 'S13.04', 'S49': 'S13.05', 'S50': 'S13.06',
    'S51': 'S13.07', 'S55': 'S13.08',
    # S14 Chụp ngay (nhiếp ảnh gia)
    'S52': 'S14.01', 'S53': 'S14.02', 'S54': 'S14.03',
    # S15 Đăng việc (khách), S16 Nhận việc đăng (nhiếp ảnh gia)
    'S56': 'S15.01', 'S57': 'S15.02', 'S58': 'S15.03', 'S59': 'S15.04',
    'S60': 'S16.01', 'S61': 'S16.02', 'S62': 'S16.03',
    # S17 Thông báo
    'S63': 'S17.01', 'S64': 'S17.02', 'S65': 'S17.03',
}

USE_CASES = {
    'S01': 'Vào app & tài khoản', 'S02': 'Khám phá & tìm thợ', 'S03': 'Xem hồ sơ nhiếp ảnh gia',
    'S04': 'Đặt lịch', 'S05': 'Theo dõi buổi chụp (khách)', 'S06': 'Nhận việc (nhiếp ảnh gia)',
    'S07': 'Hội thoại', 'S08': 'Thiết lập hồ sơ nhiếp ảnh gia', 'S09': 'Hồ sơ cá nhân & cài đặt',
    'S10': 'Đăng bài', 'S11': 'Tham gia sự kiện', 'S12': 'Tổ chức sự kiện', 'S13': 'Chụp ngay (khách)',
    'S14': 'Chụp ngay (nhiếp ảnh gia)', 'S15': 'Đăng việc (khách)', 'S16': 'Nhận việc đăng (nhiếp ảnh gia)',
    'S17': 'Thông báo',
}

SCREENS_OF = {}
for new in MAP.values():
    SCREENS_OF.setdefault(new[:3], []).append(new)


def describe(old_codes):
    """Smallest description of a set of screens: whole use cases as Sxx, others as Sxx.yy."""
    news = sorted({MAP[c] for c in old_codes if c in MAP})
    out = []
    for uc in sorted({n[:3] for n in news}):
        mine = [n for n in news if n[:3] == uc]
        if sorted(mine) == sorted(SCREENS_OF[uc]):
            out.append(uc)
        elif len(mine) > 2 and [int(n[4:]) for n in mine] == list(range(int(mine[0][4:]), int(mine[-1][4:]) + 1)):
            out.append(f'{mine[0]}–{mine[-1]}')
        else:
            out.extend(mine)
    return ', '.join(out)


# One pass (range or single code), so a produced use-case code like `S14` is never translated again.
TOKEN = re.compile(r'\bS(\d{2})(?: ?[–-] ?S(\d{2}))?\b(?!\.\d)')


def rewrite(text):
    def sub(m):
        if m.group(2) is None:
            return MAP.get(m.group(0), m.group(0))
        a, b = int(m.group(1)), int(m.group(2))
        if a >= b:
            return m.group(0)
        return describe([f'S{i:02d}' for i in range(a, b + 1)])
    return TOKEN.sub(sub, text)


if __name__ == '__main__':
    for path in sys.argv[1:]:
        with open(path, encoding='utf-8') as f:
            before = f.read()
        after = rewrite(before)
        if after != before:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(after)
            print('rewrote', path)
