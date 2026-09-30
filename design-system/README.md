# Design System — Cộng đồng nhiếp ảnh gia

Bộ token thiết kế cho app Android booking nhiếp ảnh gia. Xây dựng theo 3 lớp:

```
Primitive  (giá trị thô: brand_500, gray_600, space_4, font_base)
    ↓
Semantic   (mục đích: color_primary, color_foreground, spacing_page_x, text_body)
    ↓
Component  (widget: button_primary_bg, card_radius, chat_bubble_me_bg)
```

Layout và drawable chỉ dùng lớp **semantic** hoặc **component**. Không dùng primitive trực tiếp, không hard‑code hex hay dp.

## File

| File | Vai trò |
|------|---------|
| `design-system/tokens.json` | Nguồn sự thật (W3C design token format) |
| `design-system/tokens.css` | Sinh tự động từ JSON, dùng cho slide/web/prototype |
| `app/src/main/res/values/tokens_colors.xml` | Màu 3 lớp cho Android |
| `app/src/main/res/values/tokens_dimens.xml` | Spacing, cỡ chữ, radius, elevation |
| `app/src/main/res/values/tokens_styles.xml` | Text appearance và style widget |
| `app/src/main/res/drawable/bg_button_*.xml`, `bg_input*.xml`, `bg_chip.xml`, `bg_card.xml`, `bg_badge_*.xml`, `bg_chat_bubble_*.xml` | Drawable dựng từ token |
| `app/src/main/res/color/selector_chip_fg.xml` | Color state list cho chip |

Sinh lại CSS sau khi sửa JSON:

```bash
node ~/.claude/skills/design-system/scripts/generate-tokens.cjs \
  --config design-system/tokens.json -o design-system/tokens.css
```

Các file XML Android được viết tay theo JSON. Khi đổi giá trị, sửa cả hai nơi.

## 1. Màu sắc

### Bảng màu primitive

Màu thương hiệu giữ nguyên teal‑blue `#05749F` đang dùng trong app, mở rộng thành thang 10 bậc. Thang xám lấy từ các giá trị xám có sẵn trong `colors.xml` cũ.

| Thang | 50 | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900 |
|-------|----|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| brand | E6F3F8 | C2E2EE | 8FC9DE | 5BAFCC | 2E92B7 | **05749F** | 056487 | 084D68 | 063A4F | 042837 |
| gray | F7F7F7 | EFEFEF | E9E9E9 | D6D6D6 | AEAEAE | 898888 | 707070 | 565555 | 313131 | 1C1C1C |
| green | | E3F5DF | | | | 1A9F02 | | 127001 | | |
| red | | FCE4E2 | | | | E91E11 | | B21D14 | | |
| yellow | | FBF6DA | | | | E6C617 | | A88F0A | | |

### Semantic

| Token | Giá trị | Dùng cho |
|-------|---------|----------|
| `color_background` | white | Nền màn hình |
| `color_background_subtle` | gray_50 | Nền list, nền phía sau card |
| `color_surface` | white | Card, dialog, bottom sheet |
| `color_surface_muted` | gray_100 | Chip, bubble chat người khác, nút disabled |
| `color_foreground` | gray_800 | Text chính, icon |
| `color_foreground_secondary` | gray_600 | Text phụ, caption |
| `color_foreground_muted` | gray_500 | Placeholder, timestamp |
| `color_foreground_disabled` | gray_400 | Text/icon disabled |
| `color_foreground_inverse` | white | Text trên nền brand hoặc ảnh |
| `color_primary` / `_pressed` / `_subtle` | brand_500 / 700 / 50 | Hành động chính, link, icon active |
| `color_secondary` / `_pressed` | gray_100 / 200 | Hành động phụ |
| `color_destructive` / `_pressed` | red_500 / 700 | Từ chối booking, xoá, logout |
| `color_success` / `_subtle` | green_500 / 100 | Accepted, upload xong |
| `color_warning` / `_subtle` | yellow_500 / 100 | Dự án đang mở |
| `color_error` / `_subtle` | red_500 / 100 | Lỗi form, denied |
| `color_info` / `_subtle` | brand_500 / 50 | Thông tin, waiting |
| `color_border` / `_strong` | gray_200 / 300 | Viền card / viền input |
| `color_divider` | gray_200 | Đường kẻ list |
| `color_overlay` | #6A000000 | Scrim dialog, phủ trên ảnh hero |
| `color_overlay_light` | #88FFFFFF | Icon/text trắng mờ trên ảnh |
| `color_rating` | yellow_500 | Sao rating |

### Trạng thái booking

Ánh xạ 1:1 với enum `BookStatus`. Mỗi trạng thái có màu đặc và màu fill mờ (35% alpha) để phủ lên ảnh.

| BookStatus | Token | Fill | Drawable badge |
|------------|-------|------|----------------|
| WAITING (0) | `color_booking_waiting` = brand_500 | `color_booking_waiting_fill` | `bg_badge_waiting` |
| ACCEPTED (1) | `color_booking_accepted` = green_500 | `color_booking_accepted_fill` | `bg_badge_accepted` |
| DENIED (2) | `color_booking_denied` = red_700 | `color_booking_denied_fill` | `bg_badge_denied` |
| OPENED (3) | `color_booking_opened` = yellow_500 | `color_booking_opened_fill` | `bg_badge_opened` |
| CLOSED (4) | `color_booking_closed` = gray_500 | `color_booking_closed_fill` | `bg_badge_closed` |

### Độ tương phản (WCAG AA trên nền trắng)

| Màu | Tỉ lệ | Kết luận |
|-----|-------|----------|
| gray_800 `#313131` | 12.6:1 | Text chính, đạt AAA |
| gray_600 `#707070` | 4.9:1 | Text phụ, đạt AA |
| gray_500 `#898888` | 3.5:1 | Chỉ dùng cho text ≥ 18sp hoặc placeholder |
| gray_400 `#AEAEAE` | 2.3:1 | Chỉ dùng cho disabled, không dùng cho text đọc được |
| brand_500 `#05749F` | 5.3:1 | Text link và nút, đạt AA |
| yellow_500 `#E6C617` | 1.7:1 | Không đặt text trắng lên; badge OPENED nên dùng text gray_800 |

Lưu ý: `colorAccent` cũ (`#aeaeae`) không đủ tương phản. Khi cập nhật theme, đặt `colorAccent` = `@color/color_primary`.

### Dark mode

`tokens.json` có sẵn khối `dark` override lớp semantic (nền gray_900, text gray_50, primary brand_300). Chưa tạo `values-night/` vì app đang dùng Support Library 26 chưa hỗ trợ `DayNight` ổn định. Khi nâng lên AndroidX, copy khối này thành `values-night/tokens_colors.xml` chỉ chứa các token semantic.

## 2. Typography

Font: mặc định hệ thống (Roboto) qua `sans-serif` và `sans-serif-medium`. App hiện không có font riêng, không thêm.

| Style | Cỡ | Weight | Màu | Dùng cho |
|-------|----|--------|-----|----------|
| `Text.Display` | 35sp | medium | foreground | Tên app ở màn login |
| `Text.Headline` | 24sp | medium | foreground | Tiêu đề màn hình trong body |
| `Text.Title` | 20sp | medium | foreground | Toolbar title, tên nhiếp ảnh gia |
| `Text.Subtitle` | 16sp | medium | foreground | Tên trong list, tiêu đề card |
| `Text.Body` | 14sp | regular | foreground | Nội dung chính |
| `Text.Body.Secondary` | 14sp | regular | foreground_secondary | Mô tả |
| `Text.Caption` | 12sp | regular | foreground_secondary | Địa chỉ, thời gian, giá |
| `Text.Caption.Muted` | 12sp | regular | foreground_muted | Timestamp chat |
| `Text.Overline` | 10sp | regular, caps, +8% tracking | foreground_muted | Nhãn nhỏ, label section |

Biến thể màu: `.Primary` (brand), `.Inverse` (trắng), `.OnImage` (trắng 53%).

Cách dùng trong layout:

```xml
<TextView style="@style/Text.Subtitle" ... />
<TextView style="@style/Text.Caption.Muted" ... />
```

Hoặc `android:textAppearance="@style/Text.Caption"` nếu muốn giữ style khác.

## 3. Spacing

Lưới 4dp. Primitive `space_N` = N × 4dp.

| Token | dp | Semantic |
|-------|----|----------|
| `space_1` | 4 | `spacing_inline_tight` — icon và text sát nhau |
| `space_2` | 8 | `spacing_inline` — giữa các phần tử trong một hàng |
| `space_3` | 12 | `spacing_list_item` — padding dọc của row |
| `space_4` | 16 | `spacing_page_x` — lề trái/phải màn hình, padding card |
| `space_5` | 20 | `spacing_page_y` — lề trên/dưới nội dung |
| `space_6` | 24 | `spacing_section` — giữa các section |
| `space_8` | 32 | chip height, avatar xs |
| `space_10` | 40 | avatar sm |
| `space_12` | 48 | button/input height, avatar md, touch target tối thiểu |
| `space_16` | 64 | avatar lg |

## 4. Shape và elevation

| Token | Giá trị | Dùng cho |
|-------|---------|----------|
| `radius_sm` | 4dp | Badge trạng thái, góc "đuôi" bubble chat |
| `radius_md` | 8dp | Button, input, card, ảnh thumbnail |
| `radius_lg` | 12dp | Dialog, bubble chat |
| `radius_full` | 999dp | Chip, avatar |
| `elevation_1` | 2dp | Card trong list |
| `elevation_2` | 4dp | Toolbar khi scroll, FAB |
| `elevation_3` | 8dp | Dialog, bottom sheet |
| `stroke_hairline` | 0.8dp | Divider |
| `stroke_thin` | 1dp | Viền input, card, outline button |
| `stroke_thick` | 2dp | Viền input focus, viền avatar |

## 5. Component specs

### Button

| | Primary | Outline | Danger | Text |
|--|---------|---------|--------|------|
| Style | `Button.Primary` | `Button.Outline` | `Button.Danger` | `Button.Text` |
| Nền default | primary | trong suốt, viền primary | destructive | trong suốt |
| Nền pressed | primary_pressed | primary_subtle | destructive_pressed | ripple |
| Nền disabled | surface_muted | viền foreground_disabled | surface_muted | – |
| Chữ | trắng, 14sp medium | primary | trắng | primary |
| Cao | 48dp (`Button.Small`: 32dp) | | | |
| Radius | 8dp | | | |

Dùng: Primary cho "Đặt lịch", "Đăng nhập", "Lưu". Outline cho hành động phụ cùng hàng. Danger cho "Từ chối", "Xoá". Text cho "Bỏ qua", "Huỷ" trong dialog.

### Input (`Input` style, nền `bg_input`)

| Trạng thái | Viền | Nền |
|-----------|------|-----|
| Default | 1dp border_strong | surface |
| Focus | 2dp focus_ring | surface |
| Error | 2dp error (`bg_input_error`) | surface |
| Disabled | 1dp border | surface_muted |

Cao 48dp, padding ngang 12dp, placeholder màu foreground_muted.

### Card (`Card` style hoặc `bg_card`)

Nền surface, radius 8dp, elevation 2dp (hoặc viền 1dp border khi không dùng CardView), padding 16dp, khoảng cách giữa các card 12dp. Ảnh trong card cao 180dp (`image_card_height`).

### Badge trạng thái booking (`Badge` + `bg_badge_*`)

Cao 24dp, padding ngang 8dp, radius 4dp, chữ 10sp medium viết hoa màu trắng. Riêng OPENED (nền vàng) đặt `android:textColor="@color/color_foreground"`.

### Chip khoảng giá (`Chip` + `bg_chip` + `selector_chip_fg`)

Cao 32dp, radius full. Default: nền surface_muted, chữ foreground_secondary. Selected (`android:state_selected`): nền primary, chữ trắng. Dùng cho 5 mức trong `PriceEnum`.

### Avatar

| Token | dp | Nơi dùng |
|-------|----|----------|
| `avatar_xs` | 32 | Bubble chat |
| `avatar_sm` | 40 | Row list messenger, comment |
| `avatar_md` | 48 | Card dự án, header drawer |
| `avatar_lg` | 64 | Card nhiếp ảnh gia |
| `avatar_xl` | 96 | Header profile |

Viền 2dp màu background khi đặt trên ảnh cover.

### Chat bubble

Tin của tôi: `bg_chat_bubble_me` (nền primary, chữ trắng, góc dưới phải 4dp). Tin người khác: `bg_chat_bubble_you` (nền surface_muted, chữ foreground, góc dưới trái 4dp). Padding 12dp, rộng tối đa 260dp, timestamp dùng `Text.Caption.Muted`.

### Dialog

Nền surface, radius 12dp, padding 20dp, rộng tối thiểu 280dp, scrim `color_overlay`. Nút: một Primary bên phải, một Text bên trái.

### Toolbar

Cao 56dp, nền background, title `Text.Title`. Khi đè lên ảnh hero (profile, book) dùng icon màu `toolbar_fg_on_image`.

## 6. Migration từ resource cũ

Các file cũ (`colors.xml`, `dimens.xml`, `styles.xml`) vẫn giữ nguyên để không phá layout. Khi sửa một màn hình, thay theo bảng này rồi xoá dần tên cũ.

### Màu

| Cũ | Mới |
|----|-----|
| `colorPrimary` (#fff) | `color_background` |
| `colorAccent` (#aeaeae) | `color_primary` (theme) hoặc `color_foreground_disabled` |
| `colorDark`, `blue` | `color_primary` |
| `blue_dark` | `color_primary_pressed` |
| `blue_transfer` | `color_booking_waiting_fill` |
| `text_color` | `color_foreground_secondary` |
| `text_black` | `color_foreground` |
| `gray_light` | `color_surface_muted` |
| `gray` | `gray_700` (primitive, nên đổi sang `color_foreground_secondary`) |
| `divider` | `color_divider` |
| `white_transfer` | `color_overlay_light` |
| `background_box` | `color_overlay` |
| `gray_transfer` | `color_overlay` |
| `red`, `gray_red`, `pink` | `color_destructive` / `color_error` |
| `red_dark` | `color_destructive_pressed` |
| `red_transfer` | `color_booking_denied_fill` |
| `green` | `color_success` |
| `green_transfer` | `color_booking_accepted_fill` |
| `yellow_transfer` | `color_booking_opened_fill` |
| `closed_transfer` | `color_booking_closed_fill` |
| `bg_view_color` | `gray_900` (chỉ dùng ở màn xem ảnh full‑screen) |
| Hex trong layout `#088ffffff` | `color_overlay_light` |
| Hex `#084d68`, `#05749f` | `color_primary_pressed`, `color_primary` |
| Hex `#e6c617` | `color_rating` |
| Hex `#898888`, `#acacac`, `#c1c0c0` | `color_foreground_muted` / `color_border_strong` |

### Kích thước

| Cũ | Mới |
|----|-----|
| `text_size_big` 20sp | `text_title` |
| `text_size_default` 14sp | `text_body` |
| `text_size_small` 12sp | `text_caption` |
| `text_size_tiny` 10sp | `text_overline` |
| `35sp` (login) | `text_display` |
| `17sp` | `text_subtitle` (16sp) |
| `margin_tiny` 5dp | `space_1` (4dp) |
| `margin_small` 10dp, `padding_small` 8dp | `space_2` (8dp) |
| `padding_normal` 13dp | `space_3` (12dp) |
| `margin_default` 14dp, `padding_default` 15dp | `space_4` (16dp) |
| `margin_big`, `padding_big` 20dp | `space_5` |
| `margin_large` 30dp | `space_8` (32dp) hoặc `space_6` (24dp) tuỳ ngữ cảnh |
| `margin_supper` 50dp | `space_12` (48dp) |
| `radius_small` 5dp | `radius_sm` |
| `radius_normal` 10dp, `radius_image` 8dp | `radius_md` |
| `avatar_size_small` 40dp | `avatar_sm` |
| `avatar_small_size` 50dp, `avatar_size` 60dp | `avatar_md` / `avatar_lg` |
| `avatar_size_big` 90dp | `avatar_xl` |
| `line_size` 0.8dp | `divider_thickness` |
| `image_home_height` 180dp | `image_card_height` |
| `find_image_popular_height` 200dp | `image_hero_height` |

### Style

| Cũ | Mới |
|----|-----|
| `TextViewDefault` | `Text.Body.Secondary` |
| `TextViewDefault.White` | `Text.Body.Inverse` |
| `TextViewSmall` | `Text.Caption` |
| `TextViewSmall.Blue` | `Text.Caption.Primary` |
| `bg_booking_waiting` ... `bg_booking_closed` | `bg_badge_waiting` ... `bg_badge_closed` |
| `bg_blue_small_border_selector` | `bg_button_outline` |
| `bg_red_small_border_selector` | `bg_button_danger` |
| `bg_color_primary_selector` | `bg_button_primary` |
| `bg_white_rounded` | `bg_card` |

### Cập nhật theme (khi sẵn sàng)

```xml
<style name="AppTheme" parent="Theme.AppCompat.Light.NoActionBar">
    <item name="colorPrimary">@color/color_background</item>
    <item name="colorPrimaryDark">@color/color_background</item>
    <item name="colorAccent">@color/color_primary</item>
    <item name="android:textColorPrimary">@color/color_foreground</item>
    <item name="android:textColorSecondary">@color/color_foreground_secondary</item>
    <item name="android:windowBackground">@color/color_background</item>
    <item name="buttonStyle">@style/Button.Primary</item>
    <item name="editTextStyle">@style/Input</item>
</style>
```

## 7. Quy ước

- Tên token Android: `snake_case`, tiền tố theo lớp: primitive không tiền tố (`brand_500`, `space_4`), semantic `color_*` / `spacing_*` / `text_*`, component `<widget>_<property>`.
- `android:letterSpacing` trong style chỉ có tác dụng từ API 21; trên API 15‑20 bị bỏ qua, không lỗi.
- Không thêm màu mới vào `colors.xml` cũ. Màu mới đi vào `tokens.json` trước, rồi vào lớp primitive của `tokens_colors.xml`, rồi tạo alias semantic.
