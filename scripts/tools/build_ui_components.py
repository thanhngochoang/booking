"""Builds docs/design/ui-components.html, the shared-component gallery.

The page reuses the screen mock's <style> and the (brand-only) icon sprite (docs/design/ui-mock.html), so both pages
always share one look. Each tile shows a component, its API line, the screens that use it and its
skeleton. Run from the repo root: python3 scripts/tools/build_ui_components.py
"""
import html
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOCK = ROOT / 'docs/design/ui-mock.html'
OUT = ROOT / 'docs/design/ui-components.html'
SPEC = ROOT / 'docs/superpowers/specs/components/shared-components.md'

mock = MOCK.read_text(encoding='utf-8')
STYLE = re.search(r'<style>(.*?)</style>', mock, re.S).group(1)
SPRITE = re.search(r'<svg width="0" height="0".*?</svg>', mock, re.S).group(0)
APT = re.search(r'<svg class="apt run" viewBox="0 0 100 100" aria-hidden="true">.*?</svg>', mock, re.S).group(0)


# Icon family (2026-10-06): Material Symbols Rounded. Tile snippets below were written against the old sprite
# ids; they are converted to <span class="ms"> at the end (same map as the mock, see shared-components.md "Icons").
ICON_MAP = {'home': 'home', 'explore': 'explore', 'search': 'search', 'plus': 'add', 'cal': 'calendar_today', 'user': 'person',
            'chat': 'chat_bubble', 'heart': 'favorite', 'save': 'bookmark', 'share': 'ios_share', 'back': 'arrow_back',
            'pin': 'location_on', 'check': 'check', 'bell': 'notifications', 'cam': 'photo_camera', 'more': 'more_horiz',
            'gear': 'settings', 'moon': 'dark_mode', 'mail': 'mail', 'lock': 'lock', 'arrow': 'arrow_forward', 'phone': 'call',
            'card': 'credit_card', 'swap': 'swap_horiz', 'star': 'star', 'bolt': 'bolt', 'ticket': 'confirmation_number',
            'award': 'workspace_premium', 'brief': 'work', 'x': 'close', 'undo': 'undo', 'info': 'info', 'grip': 'drag_handle',
            'chev': 'chevron_right', 'album': 'photo_library', 'list': 'format_list_bulleted', 'img': 'image'}
KEEP_SVG = {'whatsapp', 'zalo', 'logo', 'seal', 'tomato', 'brick'}


def to_ms(snippet):
    def rep(m):
        attrs, name = m.group(1), m.group(2)
        if name in KEEP_SVG:
            return m.group(0)
        cls, sty = ['ms'], []
        c = re.search(r'class="([^"]*)"', attrs)
        if c:
            cls += c.group(1).split()
        st = re.search(r'style="([^"]*)"', attrs)
        for d in (st.group(1).split(';') if st else []):
            if ':' not in d:
                continue
            k, v = (x.strip() for x in d.split(':', 1))
            if k == 'width':
                sty.append('font-size:' + v)
            elif k == 'stroke' and v not in ('currentColor', 'none'):
                sty.append('color:' + v)
            elif k == 'transform':
                sty.append(d.strip())
        a = f' style="{";".join(sty)}"' if sty else ''
        return f'<span class="{" ".join(cls)}"{a}>{ICON_MAP[name]}</span>'
    return re.sub(r'<svg([^>]*)><use href="#i-([\w-]+)"/></svg>', rep, snippet)


def icon_rows():
    """Rows of the mapping table in shared-components.md -> Icons: (AppIcons name, symbol, in mock?)."""
    rows = []
    for line in SPEC.read_text(encoding='utf-8').splitlines():
        m = re.match(r'\| `AppIcons\.(\w+)` \| `(\w+)` \| (.+?) \|', line)
        if m:
            rows.append((m.group(1), m.group(2), m.group(3).startswith('`')))
    return rows


def wavy(n, a, r=40):
    pts = []
    for i in range(241):
        t = 2 * math.pi * i / 240
        rr = r + a * math.sin(n * t)
        pts.append(f'{50 + rr * math.cos(t):.2f} {50 + rr * math.sin(t):.2f}')
    return 'M' + ' L'.join(pts) + 'Z'


V1, V2 = wavy(12, 2.4), wavy(9, 3.2)


def loader(wave, size='', label='Đang tải'):
    cls = f'sig{(" " + size) if size else ""}'
    if wave == 'ripple':
        waves = '<span class="rip"></span><span class="rip"></span><span class="rip"></span>'
    elif wave == 'vibration':
        waves = (f'<svg class="vib v1" viewBox="0 0 100 100" aria-hidden="true"><path d="{V1}"/></svg>'
                 f'<svg class="vib v2" viewBox="0 0 100 100" aria-hidden="true"><path d="{V2}"/></svg>')
    else:
        waves = ''
    return f'<div class="{cls}" role="img" aria-label="{label}">{waves}<div class="core">{APT}</div></div>'


def dring(size='', label='Đang tải', hidden=False):
    """DotRingLoader: 12 dots on a circle, the whole ring spins; head dot largest, the rest fade into a tail."""
    dots = ''.join(f'<i style="--k:{k}"></i>' for k in range(12))
    cls = f'dring{(" " + size) if size else ""}'
    a11y = 'aria-hidden="true"' if hidden else f'role="img" aria-label="{label}"'
    return f'<div class="{cls}" {a11y}><span class="rot">{dots}</span></div>'


def busy(label, cls='pri', block=False):
    """AppButton with loading: label hidden but kept (width, accessible name), dot ring as tall as the button."""
    style = ' style="flex:none"' if block else ''
    return (f'<div class="btn {cls} busy"{style} aria-busy="true" aria-disabled="true">'
            f'<span class="lbl">{label}</span>{dring(hidden=True)}</div>')


def sk(w='100%', h='12px', r='8px', extra=''):
    return f'<span class="sk" style="width:{w};height:{h};border-radius:{r};{extra}"></span>'


def skc(size):
    return f'<span class="sk" style="width:{size}px;height:{size}px;border-radius:50%;flex:none"></span>'


GALLERY_CSS = '''
/* Gallery layout: one tile per component, real state beside its skeleton. */
.gwrap{max-width:1240px;margin:0 auto;padding-block:32px 72px}
.gnav{display:flex;flex-wrap:wrap;gap:6px;margin-top:14px}
.gnav a{font-size:12px;font-weight:600;color:var(--accent);text-decoration:none;padding:5px 10px;border-radius:999px;background:var(--accent-soft)}
.ggrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,560px),1fr));gap:16px;margin-top:16px}
.tile{border:1px solid var(--line);border-radius:var(--r3);background:var(--surface);padding:14px;display:flex;flex-direction:column;gap:10px;min-width:0}
.tile h3{font-family:var(--display);font-size:18px;font-weight:600}
.tile .api{font:12px/1.45 ui-monospace,Menlo,Consolas,monospace;color:var(--ink-2);overflow-wrap:anywhere}
.tile .use{font-size:12px;color:var(--ink-3)}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:10px}
@media (max-width:620px){.pair{grid-template-columns:1fr}}
.stage{border-radius:var(--r2);padding:12px;display:flex;flex-direction:column;gap:10px;justify-content:center;min-height:120px;position:relative;overflow:hidden;
  background:radial-gradient(circle at 0% 0%,rgba(138,63,252,calc(.16*var(--glow))),transparent 55%),var(--bg)}
.stage .lab{position:absolute;top:6px;right:8px;font-size:10px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-3)}
.row3{display:flex;gap:16px;align-items:center;justify-content:space-around;flex-wrap:wrap}
.row3 figure{margin:0;display:flex;flex-direction:column;align-items:center;gap:6px;font-size:11px;color:var(--ink-3)}
/* Icons and 60-30-10 sections */
.igrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(132px,1fr));gap:8px}
.icell{display:flex;flex-direction:column;align-items:center;gap:6px;padding:10px 6px;border:1px solid var(--line);border-radius:var(--r2);background:var(--field);text-align:center;min-width:0}
.icell .ms{font-size:28px;color:var(--ink)}
.icell .ms.on{color:var(--accent)}
.icell code{font-size:10.5px;color:var(--ink-2);overflow-wrap:anywhere}.icell small{font-size:10px;color:var(--ink-3);overflow-wrap:anywhere}
.icell.new{border-style:dashed}
.split{display:flex;height:56px;border-radius:var(--r2);overflow:hidden;border:1px solid var(--line-2)}
.split>div{display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:600;min-width:0}
.swl{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px}
.swl div{display:flex;flex-direction:column;gap:6px;font-size:11px;color:var(--ink-2)}.swl i{height:34px;border-radius:8px;border:1px solid var(--line-2)}.swl code{font-size:10.5px}
/* Skeleton: white only (no hues, dark theme included), white sweep; still under reduced motion. */
:root{--sk-fill:rgba(255,255,255,.08);--sk-edge:transparent;--sk-shine:rgba(255,255,255,.14)}
@media (prefers-color-scheme:light){:root:not([data-theme="dark"]){--sk-fill:#E6E3DE;--sk-edge:transparent;--sk-shine:rgba(255,255,255,.85)}}
:root[data-theme="light"]{--sk-fill:#E6E3DE;--sk-edge:transparent;--sk-shine:rgba(255,255,255,.85)}
:root[data-theme="dark"]{--sk-fill:rgba(255,255,255,.08);--sk-edge:transparent;--sk-shine:rgba(255,255,255,.14)}
.sk{display:block;background:var(--sk-fill);box-shadow:inset 0 0 0 1px var(--sk-edge);position:relative;overflow:hidden;flex:none}
.sk::after{content:"";position:absolute;inset:0;transform:translateX(-100%);background:linear-gradient(110deg,transparent 35%,var(--sk-shine) 50%,transparent 65%)}
.stage.plain{background:var(--bg)}
@media (prefers-reduced-motion:no-preference){.sk::after{animation:skx 1.6s linear infinite}}
@keyframes skx{to{transform:translateX(100%)}}
.mini-sheet{position:relative;background:var(--sheet-bg);border:1px solid var(--line);border-radius:22px;padding:10px 12px;display:flex;flex-direction:column;gap:8px}
'''

T = []  # (anchor, name, api, use, real, skeleton)


def tile(anchor, name, api, use, real, skel):
    T.append((anchor, name, api, use, real, skel))


# --- Loading -----------------------------------------------------------------------------------
tile('signatureloader', 'SignatureLoader · sóng tròn',
     'SignatureLoader({LoaderSize size = screen, LoaderWave wave = ripple, bool active = true, String? semanticsLabel})',
     'Tải dữ liệu cấp màn (splash, mở màn chưa biết hình khối). Một loại sóng mỗi lần.',
     f'<div class="row3"><figure>{loader("ripple")}screen 150</figure><figure>{loader("ripple","sm")}block 96</figure><figure>{loader("none","xs")}inline 56 · hàng nhỏ</figure></div>',
     '<div class="meta">Loader không có skeleton. Giảm chuyển động: lá khẩu mở, một vòng tĩnh, không sóng.</div>')
tile('signatureloader-vib', 'SignatureLoader · sóng rung',
     'SignatureLoader(wave: LoaderWave.vibration)',
     'Chờ một bên khác: cổng thanh toán (S04.04), nhiếp ảnh gia trả lời (S13.03).',
     f'<div class="row3"><figure>{loader("vibration",label="Đang chờ")}screen 150</figure><figure>{loader("vibration","sm",label="Đang chờ")}block 96</figure></div>',
     '<div class="meta">Không hiện cùng sóng tròn. Màu sóng: cyan và hồng của dải logo.</div>')
tile('asyncview', 'AsyncView · DotRingLoader',
     'AsyncView<T>({required AsyncValue<T> value, required data, skeleton, loaderSize, empty, isEmpty, onRetry, error}) · DotRingLoader({LoaderSize size = screen, Color? color, String? semanticsLabel})',
     'Mọi fetch. Có skeleton của component thì dựng skeleton; không thì vòng chấm bi xoay tròn. Lỗi → ErrorState; rỗng → EmptyState.',
     f'<div class="row3"><figure>{dring()}screen 96</figure><figure>{dring("sm")}block 64</figure></div><div class="meta" style="text-align:center">Không có skeleton thì trạng thái tải là vòng chấm bi: 12 chấm trên một vòng tròn, quay một vòng trong 1,5 s rồi nghỉ 0,5 s, chấm đầu to và rõ, các chấm sau nhỏ dần thành đuôi. Không hộp, không nền. Tải lại khi đã có dữ liệu: giữ dữ liệu, vòng chấm nhỏ ở góc. Giảm chuyển động: vòng đứng yên.</div>',
     sk('100%', '64px', '20px') + sk('100%', '64px', '20px') + sk('100%', '64px', '20px'))

# --- Cards ---------------------------------------------------------------------------------------
tile('photocard', 'PhotoCard', 'PhotoCard({imageUrl, aspect, title, subtitle, leadingPill, trailingPill, action, onTap, Widget? overlay})',
     'S02.01, S03.01, S02.03, S10.01',
     '<div class="ph" style="aspect-ratio:4/5;border-radius:var(--r3);max-height:260px"><span class="pill"><i></i>Rảnh T7 này</span><span class="pill r">Chân dung · từ 1,5M</span><div class="ov"><div class="row"><span class="av"></span><div class="grow"><b>Minh Trí</b><small>Quận 3 · ★ 4.9 (58)</small></div></div></div></div>',
     sk('100%', '260px', '20px'))
tile('photographercard', 'PhotographerCard', 'PhotographerCard({data, reasons, onProfile, onBook, bookLabel})', 'S02.01, S02.06',
     '<div class="card" style="flex-direction:column;align-items:stretch;padding:0;overflow:hidden"><div class="ph p3" style="aspect-ratio:16/9;border-radius:0"><span class="pill"><i></i>Rảnh 12/10</span></div><div class="row" style="padding:10px"><span class="av m"></span><div class="grow"><b style="font-size:13px">Minh Trí</b><div class="meta">Chân dung · 1,2 km · ★ 4.9</div></div><b class="tn">1,5M</b></div><div class="row" style="padding:0 10px 10px"><div class="btn out sm">Hồ sơ</div><div class="btn pri sm">Đặt T7</div></div></div>',
     f'<div class="card" style="flex-direction:column;align-items:stretch;padding:0;overflow:hidden">{sk("100%","130px","0")}<div class="row" style="padding:10px">{skc(40)}<div class="grow" style="display:flex;flex-direction:column;gap:6px">{sk("60%")}{sk("80%","10px")}</div>{sk("36px")}</div><div class="row" style="padding:0 10px 10px">{sk("50%","38px","14px")}{sk("50%","38px","14px")}</div></div>')
tile('bookingcard', 'BookingCard', 'BookingCard({required BookingSummary data, BookingCardSize size = normal, Widget? actions, bool highlight, VoidCallback? onTap})',
     'S04.03, S04.04, S05.01, S05.02, S06.01, S07.01',
     '<div class="card"><div class="th ph p3"></div><div class="t"><b>Minh Trí · Chân dung 2 giờ</b><span class="meta tn">T7 12/10 · 15:30–17:30</span><br><span class="meta">Bến Bạch Đằng</span></div><span class="badge b-pen">Đã gửi</span></div><div class="card"><div class="th ph p3" style="width:48px;height:48px"></div><div class="t"><b>Minh Trí · Chân dung 2 giờ</b><span class="meta">compact · cọc 450.000₫</span></div><span class="badge b-pen">Chờ cọc</span></div>',
     f'<div class="card">{sk("64px","64px","12px")}<div class="t" style="display:flex;flex-direction:column;gap:6px">{sk("70%")}{sk("50%","10px")}{sk("40%","10px")}</div>{sk("52px","18px","4px")}</div><div class="card">{sk("48px","48px","12px")}<div class="t" style="display:flex;flex-direction:column;gap:6px">{sk("70%")}{sk("45%","10px")}</div>{sk("52px","18px","4px")}</div>')
tile('dateblock', 'DateBlock',
     'DateBlock({required DateTime day, DateBlockSize size = regular, DateBlockFormat format = regular, VoidCallback? onTap})',
     'S02.03, S02.04, S11.01, S12.02, S12.03',
     '<div class="row3"><figure><div class="date"><b>26</b><span>T10</span></div>regular (46×52)</figure><figure><div class="date" style="width:38px;padding:4px 0"><b style="font-size:16px">26</b><span style="font-size:8.5px">T10</span></div>compact (38×44)</figure></div>',
     f'<div class="row3"><figure>{sk("46px","52px","14px")}regular</figure><figure>{sk("38px","44px","12px")}compact</figure></div>')
tile('eventcard', 'EventCard',
     'EventCard({required EventCardData data, EventCardSize size = row, String? distanceLabel, VoidCallback? onTap})',
     'S02.03, S02.04, S11.01, S12.02, S12.03',
     '<div class="card"><div class="date"><b>26</b><span>T10</span></div><div class="t"><b>Mini session mùa thu</b><span class="meta">Minh Trí · Công viên Bạch Đằng</span><br><span class="etag">#minisession</span></div><div style="text-align:right"><b class="tn">600K</b><div class="meta x">Còn 3 chỗ</div></div></div><div class="card"><div class="date"><b>09</b><span>T11</span></div><div class="t"><b>Cosplay ngoài trời</b><span class="meta">Thu Hà</span></div><span class="tag free">Không thu phí</span></div><div class="ph p4" style="aspect-ratio:16/10;border-radius:var(--r3)"><span class="pill"><i style="background:var(--warn)"></i>Còn 6 chỗ</span><div class="ov"><small>CN 20/10 · 06:00 · Phố cổ Hà Nội</small><b>Photo walk phố cổ buổi sớm</b><small>Quốc Bảo · 14/20 đã đăng ký</small></div></div>',
     f'<div class="card">{sk("46px","52px","14px")}<div class="t" style="display:flex;flex-direction:column;gap:6px">{sk("75%")}{sk("55%","10px")}{sk("30%","10px")}</div>{sk("36px","26px")}</div>' * 2)
tile('ticketcard', 'TicketCard',
     'TicketCard({required TicketCardData ticket, VoidCallback? onCancel, VoidCallback? onDirections, VoidCallback? onAddToCalendar, VoidCallback? onOpenChat, VoidCallback? onPay, bool compact = false}) · TicketCard.skeleton()',
     'S11.04',
     '<div class="card hi" style="flex-direction:column;align-items:stretch;gap:12px;padding:16px"><div class="row"><div class="grow"><span class="tag">Photo walk</span><div style="font-family:var(--display);font-weight:600;font-size:17px;margin-top:6px">Photo walk phố cổ</div><div class="meta tn">CN 20/10 · 06:00 · 2 vé</div></div><span class="badge b-ok">Đã đăng ký</span></div><div class="row" style="gap:12px;align-items:center"><div class="qr" aria-hidden="true"></div><div class="grow meta">Đưa mã này cho chủ sự kiện khi đến điểm hẹn.<br><br><b class="tn" style="color:var(--ink);font-size:13px">VE-7K2Q-0420</b></div></div><div class="row"><div class="btn out sm">Chỉ đường</div><div class="btn sec sm">Thêm vào lịch</div></div><div class="btn out sm" style="flex:none"><span class="ms" style="font-size:16px">chat_bubble</span>Vào nhóm chat</div></div><div class="btn txt sm">Huỷ vé · hoàn 100%</div>',
     f'<div class="card" style="flex-direction:column;align-items:stretch;gap:12px;padding:16px">{sk("40%","16px","999px")}{sk("80%","20px")}{sk("50%","12px")}<div class="row" style="gap:14px;align-items:center">{sk("112px","112px","12px")}<div class="grow" style="display:flex;flex-direction:column;gap:8px">{sk("60%","16px")}{sk("40%","12px")}</div></div><div class="row" style="gap:8px">{sk("50%","38px","14px")}{sk("50%","38px","14px")}</div></div>')
tile('statustimeline', 'StatusTimeline', 'StatusTimeline({required List<TimelineStep> steps})  · TimelineStep(title, subtitle, state: done|current|upcoming|stopped)', 'S05.02',
     '<div style="display:flex;flex-direction:column"><div class="tl done"><i></i><div><b>Đã gửi & đặt cọc</b><span>Hôm nay 9:41 · 450.000₫</span></div></div><div class="tl now"><i></i><div><b>Chờ Minh Trí nhận</b><span>Thường trong 1 giờ</span></div></div><div class="tl"><i></i><div><b>Đã xác nhận</b></div></div></div>',
     ''.join(f'<div class="row" style="gap:10px">{skc(14)}<div class="grow" style="display:flex;flex-direction:column;gap:5px">{sk("55%")}{sk("35%","9px")}</div></div>' for _ in range(3)))
tile('stattile', 'StatTile', 'StatTile({required String value, required String label, VoidCallback? onTap}) · StatTile.skeleton()', 'S03.01, S06.01, S12.03, S06.05',
     '<div class="row" style="gap:8px"><div class="kpi"><b>12,4M</b><span>Tháng này</span></div><div class="kpi"><b>3,2M</b><span>Đang giữ</span></div><div class="kpi"><b>5</b><span>Buổi sắp tới</span></div></div>',
     f'<div class="row" style="gap:8px">' + ''.join(f'<div class="kpi" style="gap:6px">{sk("70%","20px")}{sk("80%","9px")}</div>' for _ in range(3)) + '</div>')
tile('verdictpad', 'VerdictPad · VerdictLevel',
     'VerdictPad({required VerdictKind? kind, required int hits, required onChanged(kind, hits), compact = false, enabled = true}) · VerdictLevel({kind, hits, label, onReset}) · verdictLevelLabel(l10n, kind, hits)',
     'S05.05 (khối thợ và khối studio dùng compact)',
     '<div class="vpad" role="group" aria-label="Đánh giá buổi chụp"><div class="vbtn t on" role="slider" aria-label="Ném cà chua, 7 trên 10"><span class="hit">×7</span><svg><use href="#i-tomato"/></svg>Hài lòng</div><div class="vbtn b" role="slider" aria-label="Ném gạch, 0 trên 10"><svg><use href="#i-brick"/></svg>Chưa hài lòng</div></div>'
     '<div class="vlvl"><div class="sec"><b style="font-family:var(--body);font-size:13px">Rất hài lòng</b><span>Làm lại</span></div><div class="vtrack"><i style="width:91%"></i></div><span class="meta x">Chạm tiếp để tăng mức độ, tối đa 10</span></div>'
     '<div class="vpad cp"><div class="vbtn t" role="slider" aria-label="Ném cà chua, 0 trên 10"><svg><use href="#i-tomato"/></svg>Hài lòng</div><div class="vbtn b on" role="slider" aria-label="Ném gạch, 2 trên 10"><span class="hit">×2</span><svg><use href="#i-brick"/></svg>Chưa hài lòng</div></div>'
     '<div class="vlvl"><div class="sec"><b style="font-family:var(--body);font-size:13px">Hơi tiếc</b><span>Làm lại</span></div><div class="vtrack b"><i style="width:58%"></i></div></div>',
     '<div class="meta">Không có skeleton: pad là điều khiển, không tải dữ liệu. Chạm: phe mới ×1, chạm tiếp +1, tối đa 10; đổi phe về ×1. Một cú nảy mỗi lần chạm, không hiệu ứng lặp.</div>')
tile('verdictbadge', 'VerdictBadge · TomatoRatioBar · MetaLine · VerdictIcon',
     'VerdictBadge({kind, hits}) · TomatoRatioBar({tomatoCount, brickCount}) · MetaLine(List<MetaPart>, {style, maxLines = 1}) · MetaPart.text(s) | MetaPart.tomato(pct) · VerdictIcon(kind, {size = 16, color})',
     'S03.01 (tab Đánh giá, thẻ thợ, hàng kết quả), S02.01, S02.02, S02.06, S12.02, S15.03',
     '<div class="row" style="gap:12px"><b class="tn tm l" style="font-family:var(--display);font-size:26px;font-weight:600"><svg style="width:24px;height:24px"><use href="#i-tomato"/></svg>97%</b><div class="grow"><div class="vratio" role="img" aria-label="56 cà chua, 2 gạch"><i style="flex:56"></i><i style="flex:2"></i></div><div class="meta tn" style="margin-top:5px">56 cà chua · 2 gạch · 58 đánh giá</div></div></div>'
     '<div class="row" style="gap:8px"><span class="vbdg t"><svg><use href="#i-tomato"/></svg>×10</span><span class="vbdg b"><svg><use href="#i-brick"/></svg>×3</span></div>'
     '<div class="meta">Chân dung · Quận 3 · <span class="tm"><svg><use href="#i-tomato"/></svg>97%</span> · 112 buổi</div>',
     '<div style="display:flex;flex-direction:column;gap:8px">' + sk("100%", "8px", "999px") + sk("45%", "11px") + '</div>')
tile('capacity', 'CapacityBar · CompletenessMeter', 'CapacityBar({registered, capacity}) · CompletenessMeter({int? percent, String? hint})', 'S11.02, S12.03, S08.02, S09.02',
     '<div><div class="row" style="justify-content:space-between"><b style="font-size:12.5px">14 / 20 đã đăng ký</b><span class="meta x">Còn 6 chỗ</span></div><div class="cbar" style="margin-top:6px"><i style="width:70%"></i></div></div><div><div class="row" style="justify-content:space-between"><b style="font-size:12.5px">Độ khớp hồ sơ</b><b class="tn">72%</b></div><div class="cbar" style="margin-top:6px"><i style="width:72%"></i></div></div>',
     f'<div style="display:flex;flex-direction:column;gap:6px">{sk("60%")}{sk("100%","6px","3px")}</div><div style="display:flex;flex-direction:column;gap:6px">{sk("50%")}{sk("100%","6px","3px")}</div>')
tile('calendar', 'AvailabilityCalendar', 'AvailabilityCalendar({month, states, selected, onSelect, minDate, maxDate, today, ...})', 'S03.01, S02.06, S04.02, S06.04',
     '<div class="cal"><span class="h">T2</span><span class="h">T3</span><span class="h">T4</span><span class="h">T5</span><span class="h">T6</span><span class="h">T7</span><span class="h">CN</span><span class="off">7</span><span>8</span><span>9</span><span class="busy">10</span><span>11</span><span class="sel">12</span><span class="pend">13</span></div>',
     '<div class="cal">' + ''.join(f'<span style="padding:0">{sk("100%","24px","10px")}</span>' for _ in range(14)) + '</div>')
tile('identity', 'AppAvatar · VerifiedMark · ReasonChips', 'AppAvatar({url, name, size = md}) · VerifiedMark({size}) · ReasonChips({reasons, max = 2})', 'S02.02, S03.01, S02.06, S09.01',
     '<div class="row"><span class="av m"></span><b>Minh Trí</b> <span class="vf" role="img" aria-label="Đã xác minh"><svg><use href="#i-check"/></svg></span></div><div class="row" style="flex-wrap:wrap;gap:6px"><span class="chip">Chuyên chân dung</span><span class="chip">Cách 1,2 km</span></div>',
     f'<div class="row">{skc(40)}{sk("90px")}</div><div class="row" style="gap:6px">{sk("96px","26px","999px")}{sk("80px","26px","999px")}</div>')
tile('providermarks', 'ProviderMark · ProviderTag · ProviderName',
     'ProviderMark(kind: verified | artist | studio, {size}) · ProviderTag({type, awards, district, showAwards}) · ProviderName(name, {mark, style}) · providerMarkOf({type, verified})',
     'S02.01, S02.06, S03.01, S08.01',
     '<div class="row" style="gap:10px;margin-bottom:8px;flex-wrap:wrap"><span><b style="font-family:var(--display);font-size:16px">Minh Trí</b><span class="vf" role="img" aria-label="Đã xác minh"><svg><use href="#i-check"/></svg></span></span><span><b style="font-family:var(--display);font-size:16px">Hoàng Vũ</b><span class="vf gold" role="img" aria-label="Nhiếp ảnh gia đã duyệt"><svg><use href="#i-check"/></svg></span></span><span><b style="font-family:var(--display);font-size:16px">Studio Mây</b><span class="vfs" role="img" aria-label="Studio đã xác minh"><svg><use href="#i-seal"/></svg></span></span></div>'
     '<div class="row" style="gap:6px;flex-wrap:wrap"><span class="ptag nag"><svg><use href="#i-award"/></svg>Nhiếp ảnh gia · 7 giải</span><span class="ptag"><svg><use href="#i-brief"/></svg>Studio · Hoàn Kiếm</span></div>',
     '<div class="meta">Không có skeleton (không phụ thuộc dữ liệu).</div>')
tile('albums', 'AlbumTile · PortfolioViewToggle',
     'AlbumTile({title, photoCount, coverUrl, featured = false, dimmedNote, onTap}) · AlbumTile.skeleton({featured}) · PortfolioViewToggle({value: PortfolioView, onChanged})',
     'S03.01, S24.01, S24.02',
     '<div class="row" style="justify-content:flex-end;margin-bottom:8px"><span class="vtg"><span class="on"><svg><use href="#i-album"/></svg>Album</span><span><svg><use href="#i-list"/></svg>Dòng thời gian</span></span></div><div class="albs"><div class="alb feat"><div class="ph p2" style="aspect-ratio:16/7"><span class="pcnt"><svg><use href="#i-img"/></svg>12</span></div><b>Tác phẩm đạt giải</b><span>12 ảnh</span></div><div class="alb"><div class="ph p3"></div><b>Cưới Đà Lạt</b><span>24 ảnh</span></div><div class="alb" style="opacity:.7"><div class="ph p4"></div><b>Mới tạo</b><span>Trống · chưa hiện công khai</span></div></div>',
     f'<div class="albs"><div class="alb feat">{sk("100%","120px","14px","display:block")}{sk("60%","13px","6px","margin-top:6px")}</div><div class="alb">{sk("100%","110px","14px","display:block")}{sk("70%","13px","6px","margin-top:6px")}</div><div class="alb">{sk("100%","110px","14px","display:block")}{sk("70%","13px","6px","margin-top:6px")}</div></div>')
tile('reorderrow', 'ReorderableRow',
     'ReorderableRow({index, count, title, subtitle, leading, dimmed = false, onMove(newIndex), extraMenu}) · dùng trong ReorderableListView(buildDefaultDragHandles: false)',
     'S24.04',
     '<div style="display:flex;flex-direction:column;gap:6px"><div class="lrow"><div class="grip" aria-label="Kéo để sắp xếp"><svg><use href="#i-grip"/></svg></div><div class="th ph p2"></div><div class="t"><b>Tác phẩm đạt giải</b><span>9 bài · 12 ảnh</span></div><div class="ic" aria-label="Tuỳ chọn"><svg><use href="#i-more"/></svg></div></div><div class="lrow drag"><div class="grip"><svg><use href="#i-grip"/></svg></div><div class="th ph p3"></div><div class="t"><b>Cưới Đà Lạt</b><span>Đang kéo</span></div><div class="ic"><svg><use href="#i-more"/></svg></div></div><div class="lrow unsorted"><div class="grip"><svg><use href="#i-grip"/></svg></div><div class="th"><svg style="width:18px;height:18px"><use href="#i-img"/></svg></div><div class="t"><b>Chưa sắp xếp</b><span>Kéo vào vị trí</span></div><div class="ic"><svg><use href="#i-more"/></svg></div></div></div><div class="meta" style="margin-top:8px">Menu …: Chuyển lên · Chuyển xuống · Lên đầu · Xuống cuối (không cần kéo). Tay nắm 48dp, nhấn giữ để kéo; đọc "n trên m".</div>',
     f'<div class="lrow">{skc(28)}{sk("50px","50px","10px")}<div class="t" style="display:flex;flex-direction:column;gap:6px">{sk("60%","13px")}{sk("40%","10px")}</div></div>')
tile('postpicker', 'PostPickerGrid',
     'PostPickerGrid({items: List<PostPickItem>, selected: List<String>, onToggle, maxSelected}) · PostPickItem({postId, thumbUrl, imageCount = 1, albumTitle})',
     'S24.03',
     '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:4px"><div class="ph p1" style="position:relative;aspect-ratio:1"><span class="ck on">1</span><span class="pcnt" style="top:auto;bottom:6px;right:auto;left:6px">4 ảnh</span></div><div class="ph p2" style="position:relative;aspect-ratio:1"><span class="ck on">2</span></div><div class="ph p3" style="position:relative;aspect-ratio:1"><span class="ck"></span><span class="pcnt" style="top:auto;bottom:6px;right:auto;left:6px">Cưới Đà Lạt</span></div></div>',
     f'<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:4px">{sk("100%","90px","8px")}{sk("100%","90px","8px")}{sk("100%","90px","8px")}</div>')
tile('badges', 'BadgeChip · BadgeRow · BadgeTile',
     'BadgeChip({required BadgeView badge, onTap}) · BadgeRow({required List<BadgeView> badges, max = 3, onSeeAll}) · BadgeTile({required BadgeView badge, progress, isNew = false, onTap})',
     'S02.02, S03.01, S02.06, S03.02, S09.01',
     '<div class="row" style="flex-wrap:wrap;gap:6px;margin-bottom:10px"><span class="bdg"><i><svg><use href="#i-star"/></svg></i>Được đánh giá cao</span><span class="bdg"><i><svg><use href="#i-check"/></svg></i>Phản hồi nhanh</span><span class="chip" style="font-size:11px">Tất cả</span></div><div class="card" style="flex-direction:column;align-items:stretch;gap:8px;padding:12px"><div class="row" style="justify-content:space-between"><div class="ic" style="width:36px;height:36px;border-radius:50%;background:var(--cta);color:#fff"><svg style="width:20px;height:20px"><use href="#i-star"/></svg></div><span class="badge b-ok" style="font-size:9.5px;padding:2px 6px">MỚI</span></div><b style="font-size:13px">Được đánh giá cao</b><span class="meta" style="font-size:11px">Nhận tối thiểu 10 đánh giá 5 sao từ khách hàng</span><div class="cbar" style="margin-top:4px"><i style="width:70%"></i></div><span class="meta tn" style="font-size:10.5px">7 / 10 đánh giá</span></div>',
     f'<div class="row" style="gap:6px;margin-bottom:10px">{sk("120px","24px","999px")}{sk("100px","24px","999px")}{sk("50px","24px","999px")}</div><div class="card" style="flex-direction:column;align-items:stretch;gap:8px;padding:12px"><div class="row" style="justify-content:space-between">{skc(36)}{sk("40px","18px","4px")}</div>{sk("70%","14px")}{sk("90%","11px")}{sk("100%","6px","3px")}{sk("50px","10px")}</div>')

tile('awards', 'AwardChip · AwardRow',
     'AwardChip({required resultLabel, required subtitle, onTap}) · AwardChip.skeleton() · AwardRow({required title, required subtitle, status, statusLabel, onTap, onLongPress}) · awardResultTitle(l, r) · awardResultShortLabel(l, r)',
     'S03.01, S25.01',
     '<div class="row" style="gap:8px;overflow:hidden"><div class="awd"><div class="mi"><svg><use href="#i-award"/></svg></div><div style="min-width:0"><b>Huy chương Vàng</b><span>VIPA 2024 · Phong cảnh</span></div></div></div><div class="awl"><div class="aw-ic"><svg><use href="#i-award"/></svg></div><div class="t"><b>Huy chương Vàng · VIPA 2024</b><span class="badge b-ok">Đã duyệt</span> Phong cảnh</div></div><div class="awl"><div class="aw-ic mute"><svg><use href="#i-award"/></svg></div><div class="t"><b>Khuyến khích · Ảnh Đẹp VN 2022</b><span class="badge b-pen">Chờ duyệt</span> gửi 03/10</div></div>',
     f'<div class="awd" style="gap:8px">{skc(30)}<div style="flex:1;display:flex;flex-direction:column;gap:4px">{sk("80%","12px")}{sk("60%","10px")}</div></div><div class="awl">{skc(30)}<div class="t" style="display:flex;flex-direction:column;gap:6px">{sk("60%","13px")}{sk("40%","10px")}</div></div>')

tile('earningrow', 'EarningRow',
     'EarningRow({required title, required meta, required amount, required amountLabel, required badge, note, noteIcon, onTap}) · EarningRow.skeleton()',
     'S06.05',
     '<div class="card"><div class="t"><b>Lan Anh · Chân dung 2h</b><span class="meta">T7 12/10</span></div><div style="text-align:right"><b class="tn" style="font-size:13px">450K</b><div style="margin-top:3px"><span class="badge b-pen">Đang giữ</span></div></div></div><div class="card" style="flex-direction:column;align-items:stretch;gap:4px"><div class="row"><div class="t"><b>Thu Hà · Kỷ yếu</b><span class="meta">T5 10/10</span></div><div style="text-align:right"><b class="tn" style="font-size:13px">900K</b><div style="margin-top:3px"><span class="badge b-bad">Đang khiếu nại</span></div></div></div><span class="meta">Lý do: Khách đã báo vấn đề, đang chờ xử lý</span></div>',
     f'<div class="card"><div class="t" style="display:flex;flex-direction:column;gap:6px">{sk("70%","13px")}{sk("30%","10px")}</div><div style="display:flex;flex-direction:column;gap:6px;align-items:flex-end">{sk("40px","14px")}{sk("64px","18px")}</div></div>')

# --- Controls --------------------------------------------------------------------------------------
tile('buttons', 'AppButton', 'AppButton.primary|outline|secondary|danger|text({label, onPressed, loading, size = regular|small|xsmall})', 'Mọi màn (một nút chính mỗi màn)',
     f'<div class="btn pri" style="flex:none">Đặt cọc 450.000₫</div><div class="row"><div class="btn out sm">Giữ lịch</div><div class="btn dng sm">Huỷ buổi chụp</div></div>{busy("Đặt cọc 450.000₫", block=True)}<div class="row">{busy("Giữ lịch", "out sm")}{busy("Huỷ buổi chụp", "dng sm")}</div>',
     '<div class="meta">Nút không có skeleton (không chờ dữ liệu). Đang gửi (<code>loading</code>): nhãn ẩn nhưng giữ bề rộng và tên đọc, vòng chấm bi xoay tròn cao bằng lòng nút, màu theo chữ của nút; nút khoá nhưng không mờ. Giảm chuyển động: vòng chấm đứng yên.</div>')
tile('chips', 'AppChip · SegmentedTabs · AppOptionTile', 'AppChip({label, selected, onChanged, kind}) · SegmentedTabs<T>({options, value, onChanged}) · AppOptionTile({title, subtitle, selected, onTap})', 'S02.01, S02.06, S05.01, S04.01, S02.05',
     '<div class="chips"><span class="chip on">Dành cho bạn</span><span class="chip">Chân dung</span><span class="chip ac">T7 12/10</span></div><div class="seg"><span class="on">Sắp tới</span><span>Đang chờ</span><span>Đã xong</span></div><div class="opt on"><div class="th ph p3"></div><div class="grow"><b>Chân dung 2 giờ</b><span class="meta">40 ảnh · 1 địa điểm</span></div><span class="pr">1.500.000₫</span></div>',
     f'<div class="row" style="gap:6px">{sk("96px","30px","999px")}{sk("80px","30px","999px")}{sk("72px","30px","999px")}</div>{sk("100%","36px","16px")}<div class="opt">{sk("48px","48px","10px")}<div class="grow" style="display:flex;flex-direction:column;gap:6px">{sk("60%")}{sk("45%","9px")}</div>{sk("70px")}</div>')
tile('hashtagchip', 'HashtagChip', 'HashtagChip({tag, count, onTap})', 'S11.05',
     '<div class="row"><span class="chip on">#PhotoWalkPhoCo1020</span><span class="meta x tn">48 bài</span></div>',
     f'<div class="row" style="gap:8px">{sk("150px","30px","999px")}{sk("40px","12px")}</div>')
tile('stepprogress', 'StepProgress', 'StepProgress({current, total, label, showCount = true})', 'S04.01–S04.03, S08.01, S12.01, S12.02',
     '<div class="row"><div class="prog grow"><i class="on"></i><i class="on"></i><i></i><i></i></div><span class="meta x tn">2 / 4</span></div>',
     '<div class="meta">Không có skeleton (không phụ thuộc dữ liệu).</div>')
tile('phonefield', 'PhoneField', 'PhoneField({controller, errorText, international, label, ...})', 'S04.03, S04.05, S08.05, S09.03, S11.03',
     '<div class="row" style="gap:8px"><div class="field" style="flex:0 0 72px"><small>Mã</small>+84</div><div class="field grow foc"><small>Số điện thoại</small><span class="tn">903 123 456</span></div></div>',
     f'<div class="row" style="gap:8px">{sk("72px","48px","16px")}{sk("100%","48px","16px")}</div>')
tile('qtystepper', 'QtyStepper', 'QtyStepper({value, onChanged, valueLabel, decrementLabel, incrementLabel, min = 1, max, enabled = true, keyPrefix = "qty"})', 'S04.01, S11.03',
     '<div class="row3"><figure><div class="stepper"><span>−</span><b>2</b><span>+</span></div>giữa khoảng</figure><figure><div class="stepper"><span style="opacity:.4">−</span><b>1</b><span>+</span></div>tại min</figure><figure><div class="stepper"><span>−</span><b>4</b><span style="opacity:.4">+</span></div>tại max</figure></div>',
     '<div class="meta">Điều khiển nhỏ, không có skeleton: hiện cùng hàng chứa nó.</div>')
tile('contactdial', 'ContactDial', 'ContactDial({access, channels, onSelected, style, busy})', 'S05.02, S05.04, S06.01, S11.02, S12.03',
     '<div class="row" style="gap:8px;padding-top:76px"><div class="btn out sm">Nhắn tin</div><div class="cdial open" data-static="1" style="flex:1"><div class="cbtn" style="width:100%;height:38px;border-radius:14px;font-size:12px"><svg style="width:16px;height:16px"><use href="#i-phone"/></svg>Liên hệ</div><div class="copts"><div class="copt"><span class="ci st"><svg><use href="#i-phone"/></svg></span>Gọi</div><div class="copt"><span class="ci"><svg><use href="#i-zalo"/></svg></span>Zalo</div><div class="copt"><span class="ci"><svg><use href="#i-whatsapp"/></svg></span>WhatsApp</div></div></div></div>',
     f'<div class="row" style="gap:8px">{sk("50%","38px","14px")}{sk("50%","38px","14px")}</div>')

# --- Money and decisions -------------------------------------------------------------------------------
tile('escrownotice', 'EscrowNotice', 'EscrowNotice({required String text})', 'S04.03, S05.02, S11.03, S11.04, S06.05, S13.01, S13.07',
     '<div class="esc"><svg><use href="#i-lock"/></svg><span>Tiền cọc được giữ an toàn trên ứng dụng và chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp hoàn thành.</span></div>',
     f'<div class="esc">{skc(16)}<div class="grow" style="display:flex;flex-direction:column;gap:5px">{sk("100%","10px")}{sk("70%","10px")}</div></div>')
tile('moneybreakdown', 'MoneyBreakdown', 'MoneyBreakdown({required List<MoneyLine> lines}) · MoneyLine(label, vnd, style: normal|strong|muted)', 'S04.03, S11.03, S06.05, S13.08',
     '<div style="font-size:12.5px;display:flex;flex-direction:column;gap:4px"><div class="row"><span class="grow">Gói Chân dung 2 giờ</span><span class="tn">1.500.000₫</span></div><div class="row"><b class="grow">Đặt cọc hôm nay (30%)</b><b class="tn">450.000₫</b></div><div class="row meta x"><span class="grow">Còn lại trả tại buổi chụp</span><span class="tn">1.050.000₫</span></div></div>',
     ''.join(f'<div class="row">{sk("55%")}<span class="grow"></span>{sk("80px")}</div>' for _ in range(3)))
tile('policytable', 'PolicyTable', 'PolicyTable({required List<PolicyRow> rows, required int activeIndex})', 'S05.03, S13.08',
     '<div style="display:flex;flex-direction:column;gap:6px;font-size:12px"><div class="opt on" style="padding:8px 12px"><span class="grow">Trước 12/10 15:30 hơn 48 giờ</span><b>Hoàn 100%</b></div><div class="opt" style="padding:8px 12px"><span class="grow">Trong 24–48 giờ</span><b>Hoàn 50%</b></div><div class="opt" style="padding:8px 12px"><span class="grow">Dưới 24 giờ</span><b>Không hoàn</b></div></div>',
     ''.join(f'<div class="opt" style="padding:8px 12px">{sk("60%")}<span class="grow"></span>{sk("64px")}</div>' for _ in range(3)))
tile('reasonpicker', 'ReasonPicker', 'ReasonPicker({reasons, selected, onSelected, style = chips|radio, otherLabel, onOtherText, otherMinLength, otherMaxLength})', 'S05.03, S06.03, S13.08',
     '<div class="chips" style="flex-wrap:wrap"><span class="chip on">Đổi kế hoạch</span><span class="chip">Tìm được thợ khác</span><span class="chip">Lý do khác</span></div><div class="opt on"><span class="rd"></span><span class="grow">Kín lịch hôm đó</span></div><div class="opt"><span class="rd"></span><span class="grow">Ngoài khu vực phục vụ</span></div>',
     '<div class="meta">Danh sách lý do cố định trong app: không có skeleton.</div>')
tile('providerpicker', 'ProviderPicker', 'ProviderPicker({required PaymentProviderCode value, required onChanged})', 'S04.03, S04.04, S11.03',
     '<div class="row" style="gap:6px"><div class="btn out sm" style="border-color:var(--accent);color:var(--accent)">MoMo</div><div class="btn out sm">VNPay</div></div>',
     '<div class="meta">Không có skeleton.</div>')
tile('confirmsheet', 'ConfirmSheet', 'showConfirmSheet(context, {title, body, content, confirmLabel, keepLabel, danger = true, onConfirm})', 'S04.01, S05.03, S06.03, S09.02, S12.03, S13.08',
     '<div class="mini-sheet"><div class="grab"></div><div class="h3">Huỷ buổi chụp?</div><div class="row" style="justify-content:space-between"><span class="meta">Bạn sẽ nhận lại</span><b class="tn">450.000₫</b></div><div class="row" style="gap:8px"><div class="btn out sm">Giữ lịch</div><div class="btn dng sm">Huỷ buổi chụp</div></div></div>',
     f'<div class="mini-sheet"><div class="grab"></div>{sk("50%","16px")}<div class="row">{sk("40%")}<span class="grow"></span>{sk("80px")}</div><div class="row" style="gap:8px">{sk("50%","38px","14px")}{sk("50%","38px","14px")}</div></div>')
tile('countdown', 'CountdownRing · CountdownText', 'CountdownRing({deadline, total, size = 96}) · CountdownText({deadline, builder})', 'S06.01, S13.03, S13.06, S14.02',
     '<div class="cd" role="timer" aria-label="Còn 47 giây"><div class="ring" style="background:conic-gradient(var(--accent) 0 78%,var(--field) 78% 100%)"></div><b>47<small>giây</small></b></div><div class="btn pri sm" style="flex:none">Nhận · còn 22 giờ</div>',
     f'<div style="display:flex;justify-content:center">{skc(96)}</div>{sk("100%","38px","14px")}')

# --- Conversations ---------------------------------------------------------------------------------
tile('chat', 'ChatBubble · ChatComposer', 'ChatBubble({content, mine, state = sent|sending|failed, senderName, onRetry}) · ChatComposer({onSend, onPickImage, enabled, disabledReason})', 'S07.01, S11.06',
     '<div class="bub you">Chị ơi bé hay nhát, mình chụp ngoài công viên 20 phút nhé?</div><div class="bub me">Được anh. Em gửi ảnh outfit cả nhà.</div><div class="bub me" style="opacity:.6">Đang gửi…</div><div class="row"><div class="ic" style="background:var(--field)"><svg><use href="#i-cam"/></svg></div><div class="search" style="flex:1;height:40px;border-radius:999px">Nhập tin nhắn…</div><div class="ic" style="background:var(--cta);color:#fff"><svg><use href="#i-arrow"/></svg></div></div>',
     f'<div style="display:flex;flex-direction:column;gap:8px">{sk("70%","34px","18px")}{sk("55%","34px","18px","align-self:flex-end")}{sk("62%","34px","18px")}</div>{sk("100%","40px","999px")}')
tile('conversationrow', 'ConversationRow', 'ConversationRow({name, avatarUrl, preview, timeLabel, unread = 0, badge, onTap})', 'S07.02',
     '<div class="crow"><span class="av m"></span><div class="grow"><b>Minh Trí</b> <span class="badge b-ok" style="margin-left:4px">Đã nhận</span><span class="pv">Đẹp rồi. 15:30 gặp ở cổng công viên.</span></div><div class="rt"><span class="meta x tn">9:41</span><span class="un">2</span></div></div><div class="crow rd"><span class="av m" style="background:var(--p4)"></span><div class="grow"><b>Quốc Bảo</b><span class="pv">Bạn: Cảm ơn anh, ảnh đẹp lắm!</span></div><div class="rt"><span class="meta x tn">T2</span></div></div>',
     ''.join(f'<div class="crow">{skc(40)}<div class="grow" style="display:flex;flex-direction:column;gap:6px">{sk("45%")}{sk("80%","10px")}</div>{sk("32px","10px")}</div>' for _ in range(2)))
tile('notificationrow', 'NotificationRow',
     'NotificationRow({required NotificationRowData item, required VoidCallback onTap, required VoidCallback onMarkRead, VoidCallback? onMuteKind}) · NotificationRowData({id, required IconData icon, NotificationTone tone = neutral, title, body, timeLabel, unread, thumbUrl, groupAvatars}) · NotificationTone { neutral, success, action, danger, muted }',
     'S17.01',
     '<div class="nrow" style="border-top:0"><i class="ud" aria-hidden="true"></i><div class="nic ok"><svg><use href="#i-cal"/></svg></div><div class="nt"><b>Minh Trí đã nhận lịch</b><span>T7 12/10 · 15:30, Bến Bạch Đằng.</span></div><div class="tm">1 giờ</div></div>',
     f'<div class="row" style="gap:12px;align-items:center;margin-bottom:8px">{skc(36)}<div class="grow">{sk("120px","12px")}</div></div><div class="nrow" style="border-top:0">{skc(34)}<div class="nt" style="display:flex;flex-direction:column;gap:6px">{sk("70%")}{sk("90%","10px")}</div>{sk("30px","10px")}</div>')
tile('permissionprimer', 'PermissionPrimer',
     'PermissionPrimer({required String title, required List<PrimerBenefit> benefits, String? note, required VoidCallback onEnable, required VoidCallback onLater, bool enabling = false}) · PrimerBenefit(IconData icon, String text)',
     'S17.03',
     '<div class="mini-sheet" style="text-align:center;align-items:center;gap:12px"><div class="grab"></div><div class="ic" style="width:48px;height:48px;background:var(--accent-soft);color:var(--accent)"><svg style="width:24px;height:24px"><use href="#i-bell"/></svg></div><div class="h3" style="font-size:16px;text-align:center">Bật thông báo để biết khi Minh Trí nhận lịch</div><div class="meta" style="font-size:12px;text-align:left">Biết ngay khi lịch được nhận hoặc thay đổi<br>Nhắc trước giờ chụp, không lỡ hẹn<br>Tin nhắn mới khi app đang ở nền</div><div class="btn pri" style="width:100%">Bật thông báo</div><div class="btn txt" style="color:var(--ink);width:100%">Để sau</div><div class="meta" style="font-size:11px;text-align:center">Chọn "Để sau", chúng tôi sẽ hỏi lại sau 7 ngày.</div></div>',
     '<div class="meta">Nội dung sheet xin quyền không có dữ liệu tải từ mạng: không có skeleton (chỉ hiện sau khi người dùng thực hiện một hành động).</div>')

# --- Instant booking --------------------------------------------------------------------------------
tile('swipedeck', 'SwipeDeck', 'SwipeDeck<T>({items, cardBuilder, onLike, onSkip, onUndo, onEmpty})', 'S13.02',
     '<div class="swipe" style="min-height:250px"><div class="sc b3"><div class="ph p2"></div></div><div class="sc b2"><div class="ph p6"></div></div><div class="sc top"><div class="ph p3"></div><div class="pg"><i class="on"></i><i></i><i></i></div><span class="stamp">CHỌN</span></div></div><div class="sacts"><div class="ra sm"><svg><use href="#i-undo"/></svg></div><div class="ra no"><svg><use href="#i-x"/></svg></div><div class="ra yes"><svg><use href="#i-heart"/></svg></div></div>',
     f'{sk("100%","250px","20px")}<div class="sacts">{skc(44)}{skc(56)}{skc(56)}</div>')
tile('matchoverlay', 'MatchOverlay', 'MatchOverlay({name, myAvatar, theirAvatar, onContinue})', 'S13.04, S14.03',
     '<div class="match" style="padding:10px 0"><div class="mcam" role="img" aria-label="Đã match"><svg class="mline" viewBox="40 80 420 250" aria-hidden="true"><path class="wash" d="M180 220C140 160 320 140 340 220C360 300 200 280 180 220Z"/><path class="ln body" pathLength="1" d="M90 310C70 310 60 290 60 270L60 180C60 160 75 150 95 150L140 150C150 150 155 140 160 130L170 115C175 105 185 100 200 100L300 100C315 100 325 105 330 115L340 130C345 140 350 150 360 150L405 150C425 150 440 160 440 180L440 270C440 290 425 310 400 310L100 310C140 310 170 305 190 285C170 270 160 245 160 220C160 170 200 130 250 130C300 130 340 170 340 220C340 270 300 310 250 310C220 310 195 295 180 270C195 240 215 220 250 220C270 220 285 235 285 255C285 275 270 290 250 290C220 290 200 260 210 220C220 180 250 160 280 175C310 190 315 230 295 260C320 230 310 175 260 165C220 155 180 185 180 220C180 250 200 275 225 282C290 295 360 280 380 240C390 220 385 190 370 175C360 165 345 165 335 170C345 140 330 120 300 120L200 120C180 120 170 130 165 145C130 160 100 160 85 180C75 195 75 240 85 270C95 295 130 305 170 305"/><path class="ln btn" pathLength="1" d="M120 150C120 135 135 135 135 150M365 150C365 130 390 130 390 150"/><circle class="flash" cx="250" cy="220" r="92"/></svg><span class="av me" style="background:var(--p5)"></span><span class="av they"></span></div><b class="big">Đã match với <span class="gt">Minh Trí</span></b></div>',
     '<div class="meta">Lớp phủ chuyển tiếp, không có skeleton. Một nét liền vẽ máy ảnh, ống kính chớp, hai avatar đáp vào ống kính; giảm chuyển động thì hiện ngay đủ nét.</div>')
tile('offerstack', 'OfferStack', 'OfferStack({required List<Widget> offers})', 'S14.02',
     '<div class="ostk" style="margin-top:16px"><div class="under u2"></div><div class="under"></div><div class="card" style="position:relative;background:var(--surface);flex-direction:column;align-items:stretch"><b style="font-size:13px">Phường Bến Thành, Quận 1</b><div class="meta">2,1 km · khoảng 8 phút · 552.000₫</div></div></div>',
     f'<div style="margin-top:16px">{sk("100%","64px","20px")}</div>')

# --- States ---------------------------------------------------------------------------------------------
tile('states', 'EmptyState · ErrorState · OfflineBanner', 'EmptyState({title, body, action}) · ErrorState({message, onRetry}) · OfflineBanner()', 'Mọi màn có dữ liệu',
     '<div class="toast" style="font-size:11.5px">Đang xem dữ liệu đã lưu</div><div class="empty" style="padding:6px"><div class="ill ph p4" style="border-radius:50%;width:64px;height:64px"></div><b>Chưa có buổi chụp sắp tới</b><div class="btn pri sm" style="flex:none;padding:0 18px">Tìm nhiếp ảnh gia</div></div>',
     '<div class="meta">Trạng thái kết quả, không có skeleton.</div>')

WIDE = []  # (anchor, name, html) sections after the tiles


def swatches(items):
    return '<div class="swl">' + ''.join(
        f'<div><i style="background:{c}"></i><b>{n}</b><code>{v}</code></div>' for n, c, v in items) + '</div>'


_rows = icon_rows()
_cells = ''.join(
    f'<div class="icell{"" if inmock else " new"}"><span class="ms">{sym}</span><code>{html.escape(name)}</code><small>{sym}</small></div>'
    for name, sym, inmock in _rows)
WIDE.append(('icons', 'Icons · Material Symbols Rounded', f'''<div class="api">AppIcons.&lt;ý nghĩa&gt; · AppIcon(icon, {{selected, size, color, semanticLabel}}) · AppIconSize.sm/md/lg = 20/24/28</div>
      <div class="use">Weight 400, optical size 24. Viền (FILL 0) mặc định, đặc (FILL 1) khi đang chọn, đã lưu, đã thích. Khung nét đứt: biểu tượng chưa có trong mock. Logo Zalo, WhatsApp, logo ứng dụng và con dấu giữ SVG. {len(_rows)} biểu tượng, bảng ánh xạ ở shared-components.md.</div>
      <div class="igrid">{_cells}</div>
      <div class="row3" style="margin-top:6px"><figure><span class="ms" style="font-size:20px">home</span>20 · sm</figure><figure><span class="ms" style="font-size:24px">home</span>24 · md</figure><figure><span class="ms" style="font-size:28px">home</span>28 · lg</figure><figure><span class="ms on" style="font-size:24px;color:var(--accent)">home</span>FILL 1 · đang chọn</figure><figure><span class="ms" style="font-size:24px;color:var(--ink-3)">home</span>tab chưa chọn</figure></div>'''))
WIDE.append(('mau', 'Màu · quy tắc 60-30-10', f'''<div class="api">AppColors · CtaSurface · chỉ tím ở 10%</div>
      <div class="use">60% nền và bề mặt, 30% kính trung tính, chữ phụ, đường kẻ (không màu), 10% tím cho nút chính, tab đang chọn, mục đang chọn, link, tiến trình. Phổ màu (cyan, tím, hồng, cam, vàng) chỉ trong loader. Màu trạng thái và vàng của dấu NAG/giải thưởng ngoài quy tắc.</div>
      <div class="split" aria-label="Tỉ lệ 60-30-10 tối"><div style="flex:60;background:#0B0B10;color:#F7F7F7">60% nền · surface</div><div style="flex:30;background:#2A2833;color:#D6D6D6">30% trung tính</div><div style="flex:10;background:#B08AFF;color:#0B0B10">10%</div></div>
      <div class="split" aria-label="Tỉ lệ 60-30-10 sáng" style="margin-top:6px"><div style="flex:60;background:#F4F1EC;color:#313131">60% nền · surface</div><div style="flex:30;background:#EDE9E3;color:#313131">30% trung tính</div><div style="flex:10;background:#8338F5;color:#fff">10%</div></div>
      <h4 style="font-size:12px;color:var(--ink-3);margin-top:6px">60% · tối</h4>
      {swatches([('bg', '#0B0B10', '0B0B10'), ('surface', '#17151F', '17151F')])}
      <h4 style="font-size:12px;color:var(--ink-3)">30% · tối (trung tính)</h4>
      {swatches([('glass / field', 'rgba(255,255,255,.08)', 'trắng 8%'), ('glass-hi', 'rgba(255,255,255,.14)', 'trắng 14%'), ('ink-2', '#D6D6D6', 'D6D6D6'), ('ink-3', '#AEAEAE', 'AEAEAE'), ('line', 'rgba(255,255,255,.12)', 'trắng 12%')])}
      <h4 style="font-size:12px;color:var(--ink-3)">10% · tím</h4>
      {swatches([('accent tối', '#B08AFF', 'B08AFF'), ('CTA tối', 'linear-gradient(90deg,#8A3FFC,#6E2FD6)', '8A3FFC → 6E2FD6'), ('accent sáng', '#8338F5', '8338F5'), ('CTA sáng', 'linear-gradient(135deg,#8338F5,#702BDB)', '8338F5 → 702BDB'), ('focus', '#14E0F5', 'cyan, chỉ viền focus')])}
      <h4 style="font-size:12px;color:var(--ink-3)">60% · sáng và 30% · sáng</h4>
      {swatches([('bg', '#F4F1EC', 'F4F1EC'), ('surface', '#FFFFFF', 'FFFFFF'), ('field', '#EDE9E3', 'EDE9E3'), ('ink', '#313131', '313131')])}'''))

nav = ''.join(f'<a href="#{a}">{n.split(" · ")[0]}</a>' for a, n, *_ in T) + ''.join(f'<a href="#{a}">{n.split(" · ")[0]}</a>' for a, n, _ in WIDE)
tiles = []
for a, n, api, use, real, skel in T:
    plain = ' plain' if a in ('signatureloader', 'signatureloader-vib', 'asyncview') else ''  # loaders sit on the bare screen background
    tiles.append(f'''    <section class="tile" id="{a}">
      <h3>{n}</h3>
      <div class="api">{html.escape(api)}</div>
      <div class="use">Dùng ở: {use}</div>
      <div class="pair"><div class="stage{plain}"><span class="lab">Thật</span>{real}</div><div class="stage{plain}"><span class="lab">Skeleton</span>{skel}</div></div>
    </section>''')
for a, n, body in WIDE:
    tiles.append(f'''    <section class="tile" id="{a}" style="grid-column:1/-1">
      <h3>{n}</h3>
      {body}
    </section>''')

page = f'''<!-- Gallery shared component của app "Cộng đồng nhiếp ảnh gia" (Flutter). Sinh bởi scripts/tools/build_ui_components.py
     từ CSS và icon của docs/design/ui-mock.html; sửa script rồi chạy lại, không sửa file này bằng tay.
     Đặc tả: docs/superpowers/specs/components/shared-components.md -->
<title>Nhiếp Ảnh Gia Components</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700&family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600;9..144,700&display=swap">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200">
<style>{STYLE}{GALLERY_CSS}</style>
{SPRITE}
<div class="gwrap">
  <div class="top">
    <div class="eyebrow">Cộng đồng nhiếp ảnh gia · shared component · theme dark aurora</div>
    <div class="tog" role="group" aria-label="Chế độ giao diện"><button id="t-dark" aria-pressed="true" type="button">Tối</button><button id="t-light" aria-pressed="false" type="button">Sáng</button></div>
  </div>
  <h1>Component <span class="gt">dùng chung</span></h1>
  <p>Mỗi ô là một widget trong <code>lib/core/widgets/</code>: tên, API, màn dùng nó, trạng thái thật và skeleton của nó. Danh sách và thẻ đang tải dùng skeleton của chính component; chờ cấp màn dùng SignatureLoader với một loại sóng (tròn khi tải dữ liệu, rung khi chờ một bên khác). Màn hình đầy đủ ở mock màn.</p>
  <nav class="gnav" aria-label="Component">{nav}</nav>
  <div class="ggrid">
{to_ms(chr(10).join(tiles))}
  </div>
</div>
<script>
(function(){{
  var root=document.documentElement,d=document.getElementById('t-dark'),l=document.getElementById('t-light');
  function set(m){{root.setAttribute('data-theme',m);d.setAttribute('aria-pressed',m==='dark');l.setAttribute('aria-pressed',m==='light')}}
  d.addEventListener('click',function(){{set('dark')}});l.addEventListener('click',function(){{set('light')}});
  if(window.matchMedia&&matchMedia('(prefers-color-scheme: light)').matches&&!root.getAttribute('data-theme')){{d.setAttribute('aria-pressed','false');l.setAttribute('aria-pressed','true')}}
}})();
</script>
'''
OUT.write_text(page, encoding='utf-8')
print(f'wrote {OUT.relative_to(ROOT)}: {len(T)} components, {len(WIDE)} sections, {len(_rows)} icons')
