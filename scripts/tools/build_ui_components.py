"""Builds docs/design/ui-components.html, the shared-component gallery.

The page reuses the screen mock's <style> and icon sprite (docs/design/ui-mock.html), so both pages
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

mock = MOCK.read_text(encoding='utf-8')
STYLE = re.search(r'<style>(.*?)</style>', mock, re.S).group(1)
SPRITE = re.search(r'<svg width="0" height="0".*?</svg>', mock, re.S).group(0)
APT = re.search(r'<svg class="apt run" viewBox="0 0 100 100" aria-hidden="true">.*?</svg>', mock, re.S).group(0)


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
  background:radial-gradient(circle at 0% 0%,rgba(20,224,245,calc(.3*var(--glow))),transparent 55%),radial-gradient(circle at 100% 10%,rgba(255,69,208,calc(.26*var(--glow))),transparent 55%),var(--bg)}
.stage .lab{position:absolute;top:6px;right:8px;font-size:10px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-3)}
.row3{display:flex;gap:16px;align-items:center;justify-content:space-around;flex-wrap:wrap}
.row3 figure{margin:0;display:flex;flex-direction:column;align-items:center;gap:6px;font-size:11px;color:var(--ink-3)}
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
     f'<div class="row3"><figure>{loader("ripple")}screen 150</figure><figure>{loader("ripple","sm")}block 96</figure><figure>{loader("none","xs")}inline 56</figure></div>',
     '<div class="meta">Loader không có skeleton. Giảm chuyển động: lá khẩu mở, một vòng tĩnh, không sóng.</div>')
tile('signatureloader-vib', 'SignatureLoader · sóng rung',
     'SignatureLoader(wave: LoaderWave.vibration)',
     'Chờ một bên khác: cổng thanh toán (S04.04), nhiếp ảnh gia trả lời (S13.03).',
     f'<div class="row3"><figure>{loader("vibration",label="Đang chờ")}screen 150</figure><figure>{loader("vibration","sm",label="Đang chờ")}block 96</figure></div>',
     '<div class="meta">Không hiện cùng sóng tròn. Màu sóng: cyan và hồng của dải logo.</div>')
tile('asyncview', 'AsyncView',
     'AsyncView<T>({required AsyncValue<T> value, required data, skeleton, loaderSize, empty, isEmpty, onRetry, error})',
     'Mọi fetch. Có skeleton của component thì dựng skeleton; không thì SignatureLoader (sóng tròn). Lỗi → ErrorState; rỗng → EmptyState.',
     loader('ripple') + '<div class="meta" style="text-align:center">Không có skeleton thì trạng thái tải chính là SignatureLoader, khung đúng bằng vòng sóng ngoài (150 / 96), không thêm hộp hay nền. Tải lại khi đã có dữ liệu: giữ dữ liệu, loader inline ở góc.</div>',
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
tile('eventcard', 'EventCard · DateBlock', 'EventCard({data, size = row|featured|compact, distanceLabel, onTap}) · DateBlock({day})', 'S02.03, S02.04, S11.01, S12.02, S12.03',
     '<div class="card"><div class="date"><b>26</b><span>T10</span></div><div class="t"><b>Mini session mùa thu</b><span class="meta">Minh Trí · Công viên Bạch Đằng</span><br><span class="etag">#minisession</span></div><div style="text-align:right"><b class="tn">600K</b><div class="meta x">Còn 3 chỗ</div></div></div><div class="card"><div class="date"><b>09</b><span>T11</span></div><div class="t"><b>Cosplay ngoài trời</b><span class="meta">Thu Hà</span></div><span class="tag free">Không thu phí</span></div>',
     f'<div class="card">{sk("46px","52px","14px")}<div class="t" style="display:flex;flex-direction:column;gap:6px">{sk("75%")}{sk("55%","10px")}{sk("30%","10px")}</div>{sk("36px","26px")}</div>' * 2)
tile('ticketcard', 'TicketCard', 'TicketCard({ticket, onCancel, onDirections, onAddToCalendar})', 'S11.04',
     '<div class="card hi" style="flex-direction:column;align-items:stretch;gap:10px;padding:14px"><div class="row"><div class="grow"><span class="tag">Photo walk</span><div style="font-family:var(--display);font-weight:600;font-size:17px;margin-top:6px">Photo walk phố cổ</div><div class="meta tn">CN 20/10 · 06:00 · 2 vé</div></div><span class="badge b-ok">Đã đăng ký</span></div><div class="row" style="gap:12px"><div class="qr" aria-hidden="true" style="width:84px;height:84px"></div><b class="tn">VE-7K2Q-0420</b></div></div>',
     f'<div class="card" style="flex-direction:column;align-items:stretch;gap:10px;padding:14px">{sk("40%","16px","999px")}{sk("80%","18px")}{sk("50%","10px")}<div class="row" style="gap:12px">{sk("84px","84px","12px")}{sk("40%")}</div></div>')
tile('statustimeline', 'StatusTimeline', 'StatusTimeline({required List<TimelineStep> steps})  · TimelineStep(title, subtitle, state: done|current|upcoming|stopped)', 'S05.02',
     '<div style="display:flex;flex-direction:column"><div class="tl done"><i></i><div><b>Đã gửi & đặt cọc</b><span>Hôm nay 9:41 · 450.000₫</span></div></div><div class="tl now"><i></i><div><b>Chờ Minh Trí nhận</b><span>Thường trong 1 giờ</span></div></div><div class="tl"><i></i><div><b>Đã xác nhận</b></div></div></div>',
     ''.join(f'<div class="row" style="gap:10px">{skc(14)}<div class="grow" style="display:flex;flex-direction:column;gap:5px">{sk("55%")}{sk("35%","9px")}</div></div>' for _ in range(3)))
tile('stattile', 'StatTile', 'StatTile({required String value, required String label})', 'S03.01, S06.01, S12.03',
     '<div class="row" style="gap:8px"><div class="kpi"><b>12,4M</b><span>Tháng này</span></div><div class="kpi"><b>3,2M</b><span>Đang giữ</span></div><div class="kpi"><b>5</b><span>Buổi sắp tới</span></div></div>',
     f'<div class="row" style="gap:8px">' + ''.join(f'<div class="kpi" style="gap:6px">{sk("70%","20px")}{sk("80%","9px")}</div>' for _ in range(3)) + '</div>')
tile('capacity', 'CapacityBar · CompletenessMeter', 'CapacityBar({registered, capacity}) · CompletenessMeter({int? percent, String? hint})', 'S11.02, S12.03, S08.02, S09.02',
     '<div><div class="row" style="justify-content:space-between"><b style="font-size:12.5px">14 / 20 đã đăng ký</b><span class="meta x">Còn 6 chỗ</span></div><div class="cbar" style="margin-top:6px"><i style="width:70%"></i></div></div><div><div class="row" style="justify-content:space-between"><b style="font-size:12.5px">Độ khớp hồ sơ</b><b class="tn">72%</b></div><div class="cbar" style="margin-top:6px"><i style="width:72%"></i></div></div>',
     f'<div style="display:flex;flex-direction:column;gap:6px">{sk("60%")}{sk("100%","6px","3px")}</div><div style="display:flex;flex-direction:column;gap:6px">{sk("50%")}{sk("100%","6px","3px")}</div>')
tile('calendar', 'AvailabilityCalendar', 'AvailabilityCalendar({month, states, selected, onSelect, minDate, maxDate, today, ...})', 'S03.01, S02.06, S04.02, S06.04',
     '<div class="cal"><span class="h">T2</span><span class="h">T3</span><span class="h">T4</span><span class="h">T5</span><span class="h">T6</span><span class="h">T7</span><span class="h">CN</span><span class="off">7</span><span>8</span><span>9</span><span class="busy">10</span><span>11</span><span class="sel">12</span><span class="pend">13</span></div>',
     '<div class="cal">' + ''.join(f'<span style="padding:0">{sk("100%","24px","10px")}</span>' for _ in range(14)) + '</div>')
tile('identity', 'AppAvatar · VerifiedMark · BadgeChip · ReasonChips', 'AppAvatar({url, size}) · VerifiedMark({size}) · BadgeChip({badge}) · ReasonChips({reasons, max = 2})', 'S02.02, S03.01, S02.06, S09.01',
     '<div class="row"><span class="av m"></span><b>Minh Trí</b> <span class="vf" role="img" aria-label="Đã xác minh"><svg><use href="#i-check"/></svg></span></div><div class="row" style="flex-wrap:wrap;gap:6px"><span class="bdg"><i><svg><use href="#i-heart"/></svg></i>Được đánh giá cao</span><span class="chip">Chuyên chân dung</span><span class="chip">Cách 1,2 km</span></div>',
     f'<div class="row">{skc(40)}{sk("90px")}</div><div class="row" style="gap:6px">{sk("120px","22px","999px")}{sk("96px","26px","999px")}{sk("80px","26px","999px")}</div>')

# --- Controls --------------------------------------------------------------------------------------
tile('buttons', 'AppButton', 'AppButton.primary|outline|secondary|danger|text({label, onPressed, loading, size = regular|small|xsmall})', 'Mọi màn (một nút chính mỗi màn)',
     f'<div class="btn pri" style="flex:none">Đặt cọc 450.000₫</div><div class="row"><div class="btn out sm">Giữ lịch</div><div class="btn dng sm">Huỷ buổi chụp</div></div><div class="btn pri" style="flex:none;opacity:.9">{loader("none","xs")}</div>',
     '<div class="meta">Nút không có skeleton (không chờ dữ liệu). Đang gửi: loader inline trong nút, khoá nút.</div>')
tile('chips', 'AppChip · SegmentedTabs · AppOptionTile', 'AppChip({label, selected, onChanged, kind}) · SegmentedTabs<T>({options, value, onChanged}) · AppOptionTile({title, subtitle, selected, onTap})', 'S02.01, S02.06, S05.01, S04.01, S02.05',
     '<div class="chips"><span class="chip on">Dành cho bạn</span><span class="chip">Chân dung</span><span class="chip ac">T7 12/10</span></div><div class="seg"><span class="on">Sắp tới</span><span>Đang chờ</span><span>Đã xong</span></div><div class="opt on"><div class="th ph p3"></div><div class="grow"><b>Chân dung 2 giờ</b><span class="meta">40 ảnh · 1 địa điểm</span></div><span class="pr">1.500.000₫</span></div>',
     f'<div class="row" style="gap:6px">{sk("96px","30px","999px")}{sk("80px","30px","999px")}{sk("72px","30px","999px")}</div>{sk("100%","36px","16px")}<div class="opt">{sk("48px","48px","10px")}<div class="grow" style="display:flex;flex-direction:column;gap:6px">{sk("60%")}{sk("45%","9px")}</div>{sk("70px")}</div>')
tile('stepprogress', 'StepProgress', 'StepProgress({current, total, label, showCount = true})', 'S04.01–S04.03, S08.01, S12.01, S12.02',
     '<div class="row"><div class="prog grow"><i class="on"></i><i class="on"></i><i></i><i></i></div><span class="meta x tn">2 / 4</span></div>',
     '<div class="meta">Không có skeleton (không phụ thuộc dữ liệu).</div>')
tile('phonefield', 'PhoneField', 'PhoneField({controller, errorText, international, label, ...})', 'S04.03, S04.05, S08.05, S09.03, S11.03',
     '<div class="row" style="gap:8px"><div class="field" style="flex:0 0 72px"><small>Mã</small>+84</div><div class="field grow foc"><small>Số điện thoại</small><span class="tn">903 123 456</span></div></div>',
     f'<div class="row" style="gap:8px">{sk("72px","48px","16px")}{sk("100%","48px","16px")}</div>')
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
     '<div class="crow"><span class="av m"></span><div class="grow"><b>Minh Trí</b> <span class="badge b-ok" style="margin-left:4px">Đã đặt</span><span class="pv">Đẹp rồi. 15:30 gặp ở cổng công viên.</span></div><div class="rt"><span class="meta x tn">9:41</span><span class="un">2</span></div></div><div class="crow rd"><span class="av m" style="background:var(--p4)"></span><div class="grow"><b>Quốc Bảo</b><span class="pv">Bạn: Cảm ơn anh, ảnh đẹp lắm!</span></div><div class="rt"><span class="meta x tn">T2</span></div></div>',
     ''.join(f'<div class="crow">{skc(40)}<div class="grow" style="display:flex;flex-direction:column;gap:6px">{sk("45%")}{sk("80%","10px")}</div>{sk("32px","10px")}</div>' for _ in range(2)))
tile('notificationrow', 'NotificationRow', 'NotificationRow({item, onTap, onLongPress})', 'S17.01',
     '<div class="nrow" style="border-top:0"><i class="ud" aria-hidden="true"></i><div class="nic ok"><svg><use href="#i-cal"/></svg></div><div class="nt"><b>Minh Trí đã nhận lịch</b><span>T7 12/10 · 15:30, Bến Bạch Đằng.</span></div><div class="tm">1 giờ</div></div>',
     f'<div class="nrow" style="border-top:0">{skc(34)}<div class="nt" style="display:flex;flex-direction:column;gap:6px">{sk("70%")}{sk("90%","10px")}</div>{sk("30px","10px")}</div>')

# --- Instant booking --------------------------------------------------------------------------------
tile('swipedeck', 'SwipeDeck', 'SwipeDeck<T>({items, cardBuilder, onLike, onSkip, onUndo, onEmpty})', 'S13.02',
     '<div class="swipe" style="min-height:250px"><div class="sc b3"><div class="ph p2"></div></div><div class="sc b2"><div class="ph p6"></div></div><div class="sc top"><div class="ph p3"></div><div class="pg"><i class="on"></i><i></i><i></i></div><span class="stamp">CHỌN</span></div></div><div class="sacts"><div class="ra sm"><svg><use href="#i-undo"/></svg></div><div class="ra no"><svg><use href="#i-x"/></svg></div><div class="ra yes"><svg><use href="#i-heart"/></svg></div></div>',
     f'{sk("100%","250px","20px")}<div class="sacts">{skc(44)}{skc(56)}{skc(56)}</div>')
tile('matchoverlay', 'MatchOverlay', 'MatchOverlay({name, myAvatar, theirAvatar, onContinue})', 'S13.04, S14.03',
     '<div class="match" style="padding:10px 0"><div class="pair"><span class="av" style="background:var(--p5)"></span><span class="hk cam" aria-hidden="true"><svg viewBox="0 0 24 24"><path pathLength="60" d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle pathLength="60" cx="12" cy="13" r="3.5"/></svg></span><span class="av"></span></div><b class="big">Đã match với <span class="gt">Minh Trí</span></b></div>',
     '<div class="meta">Lớp phủ chuyển tiếp, không có skeleton. Máy ảnh vẽ dần theo nét; giảm chuyển động thì hiện ngay.</div>')
tile('offerstack', 'OfferStack', 'OfferStack({required List<Widget> offers})', 'S14.02',
     '<div class="ostk" style="margin-top:16px"><div class="under u2"></div><div class="under"></div><div class="card" style="position:relative;background:var(--surface);flex-direction:column;align-items:stretch"><b style="font-size:13px">Phường Bến Thành, Quận 1</b><div class="meta">2,1 km · khoảng 8 phút · 552.000₫</div></div></div>',
     f'<div style="margin-top:16px">{sk("100%","64px","20px")}</div>')

# --- States ---------------------------------------------------------------------------------------------
tile('states', 'EmptyState · ErrorState · OfflineBanner', 'EmptyState({title, body, action}) · ErrorState({message, onRetry}) · OfflineBanner()', 'Mọi màn có dữ liệu',
     '<div class="toast" style="font-size:11.5px">Đang xem dữ liệu đã lưu</div><div class="empty" style="padding:6px"><div class="ill ph p4" style="border-radius:50%;width:64px;height:64px"></div><b>Chưa có buổi chụp sắp tới</b><div class="btn pri sm" style="flex:none;padding:0 18px">Tìm nhiếp ảnh gia</div></div>',
     '<div class="meta">Trạng thái kết quả, không có skeleton.</div>')

nav = ''.join(f'<a href="#{a}">{n.split(" · ")[0]}</a>' for a, n, *_ in T)
tiles = []
for a, n, api, use, real, skel in T:
    plain = ' plain' if a in ('signatureloader', 'signatureloader-vib', 'asyncview') else ''  # loaders sit on the bare screen background
    tiles.append(f'''    <section class="tile" id="{a}">
      <h3>{n}</h3>
      <div class="api">{html.escape(api)}</div>
      <div class="use">Dùng ở: {use}</div>
      <div class="pair"><div class="stage{plain}"><span class="lab">Thật</span>{real}</div><div class="stage{plain}"><span class="lab">Skeleton</span>{skel}</div></div>
    </section>''')

page = f'''<!-- Gallery shared component của app "Cộng đồng nhiếp ảnh gia" (Flutter). Sinh bởi scripts/tools/build_ui_components.py
     từ CSS và icon của docs/design/ui-mock.html; sửa script rồi chạy lại, không sửa file này bằng tay.
     Đặc tả: docs/superpowers/specs/components/shared-components.md -->
<title>Nhiếp Ảnh Gia Components</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700&family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600;9..144,700&display=swap">
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
{chr(10).join(tiles)}
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
print(f'wrote {OUT.relative_to(ROOT)}: {len(T)} components')
