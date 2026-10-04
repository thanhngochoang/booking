# Chỉ chạy test bị ảnh hưởng (affected tests)

Một PR chỉ đụng một phần nhỏ của app thì không cần chạy cả ~200 file test. `app_flutter/tool/affected_test.dart` lấy danh sách file đổi từ git, dựng đồ thị phụ thuộc Dart, rồi chọn những test có thể bị ảnh hưởng. Nguyên tắc duy nhất: **khi không chắc thì chạy tất cả**. Chạy thừa test thì chấp nhận được, bỏ sót một test có thể hỏng thì không.

## Chạy ở máy

Từ `app_flutter/` (sau `flutter pub get`):

```bash
dart run tool/affected_test.dart origin/develop            # báo cáo: file đổi, test được chọn
dart run tool/affected_test.dart origin/develop -v         # thêm loại của từng file và chuỗi phụ thuộc vì sao test được chọn
dart run tool/affected_test.dart origin/develop --run      # chạy flutter test với các test đó
dart run tool/affected_test.dart origin/develop --run -- --exclude-tags golden   # sau `--` là tham số cho flutter test
dart run tool/affected_test.dart origin/develop --json     # kết quả dạng JSON
dart run tool/affected_test.dart --all --run               # bỏ qua phân tích, chạy tất cả
```

| Tuỳ chọn | Ý nghĩa |
|---|---|
| `<base-ref>` | commit/ref để so (nhánh, SHA). Không truyền thì lấy `$AFFECTED_BASE`, rồi `origin/$GITHUB_BASE_REF`; không có gì thì chạy tất cả. |
| `--list` | in báo cáo (mặc định) |
| `--run` | chạy `flutter test` với test được chọn (`$FLUTTER` đổi lệnh flutter) |
| `--all` | chọn tất cả test |
| `--json` | in JSON thay cho báo cáo |
| `--verbose`, `-v` | loại của từng file đổi, chuỗi `test ⇐ … ⇐ file đổi`, import không tìm thấy, thời gian phân tích |
| `--github-output` | ghi `scope`/`files`/`count` vào `$GITHUB_OUTPUT`, tóm tắt vào `$GITHUB_STEP_SUMMARY` |
| `--on-none=skip\|all` | không test nào bị ảnh hưởng: bỏ qua (mặc định, có cảnh báo) hoặc chạy tất cả (`$AFFECTED_ON_NONE`) |

File đổi gồm cả thay đổi đã commit, staged, chưa staged và file mới chưa track, so với merge-base của `<base-ref>` và `HEAD`. Vì vậy ở máy nó thấy đúng những gì CI sẽ thấy sau lần push tới.

## Cách hoạt động

1. **File đổi**: `git merge-base <base> HEAD`, rồi `git diff --name-only --no-renames` so với cây làm việc, cộng `git ls-files --others --exclude-standard`. `--no-renames` để một file đổi tên có cả đường dẫn cũ và mới. Không tìm được merge-base (clone nông) thì so thẳng hai cây: ra nhiều file hơn, vẫn an toàn.
2. **Đồ thị phụ thuộc**: đọc mọi file `.dart` trong `lib/` và `test/`, lấy `import`, `export`, `part`, `part of`, kể cả các URI của import có điều kiện (`if (dart.library.io) '…'`). Bộ quét chỉ đọc phần đầu file: Dart bắt buộc mọi directive đứng trước khai báo đầu tiên, nên nó dừng ở đó và không cần hiểu phần còn lại của ngôn ngữ. Không dùng `package:analyzer`: nó nặng, cần `pub get`, mà ở đây không cần gì hơn. `package:photobooking/…` trỏ vào `lib/`; `part` và thư viện của nó nối hai chiều.
3. **Đọc từ đĩa**: nhiều test đọc file bằng `File('…')`/`Directory('…')` (quy tắc mã nguồn quét `lib/`, test cấu hình đọc `android/`/`ios/`, `../docs/…/remaining-screens.md`, `../packages/domain/test/fixtures/…`). Đường dẫn được tính từ `app_flutter/` rồi so với file đổi ở mọi nơi trong repo. `File('lib/features/$name')` thành tiền tố `lib/features/`. Nếu đối số không phải chuỗi literal thì test đó chạy với mọi thay đổi.
4. **Chọn test**: từ các file đổi, đi ngược đồ thị (ai import mình, ai import người đó, …) và giữ các file `*_test.dart`. Test tự thay đổi luôn được chọn; đổi cả mã nguồn lẫn test thì lấy hợp của hai bên. Không ghép tên kiểu `foo.dart → foo_test.dart`.

`lib/core/core.dart` là barrel được phần lớn test import, nên đổi một file trong `core/` chọn khoảng 160 test, hoàn toàn nhờ đồ thị; không cần luật riêng cho thư mục `core/`.

## Từng loại file

| Thay đổi | Kết quả |
|---|---|
| `pubspec.yaml`, `pubspec.lock`, `pubspec_overrides.yaml`, `analysis_options.yaml`, `build.yaml`, `l10n.yaml`, mọi `dart_test.yaml` | **tất cả** |
| `tool/**` (bộ sinh mã, chính công cụ này), `assets/**`, asset/font/`path:` dependency khai báo trong pubspec | **tất cả** |
| `.github/workflows/flutter.yml`, `design-system/**` (sinh `tokens.g.dart` trong CI) | **tất cả** |
| `lib/**/*.dart`, `test/**/*.dart` | đồ thị phụ thuộc |
| mã sinh (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.config.dart`, `*.mocks.dart`) | qua `part`/import về thư viện gốc; không tìm được thư viện gốc (`x.g.dart` → `x.dart`) thì **tất cả** |
| file không phải Dart trong `lib/l10n/` (`.arb`) | mọi file Dart trong `lib/l10n/`, rồi theo đồ thị |
| file không phải Dart trong `test/` (golden, fixture) | mọi test trong thư mục gần nhất có test (golden trong `test/core/widgets/goldens/` → `test/core/widgets/**`) |
| `flutter_test_config.dart` | mọi test trong thư mục đó và thư mục con (flutter test tự nạp nó, không ai import) |
| `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/`, `firebase/**`, `*.md`, `.gitignore`, `.metadata` | chỉ những test đọc chúng từ đĩa (`flutter test` không build native) |
| file ngoài `app_flutter/` (docs, `packages/domain`, workflow khác) | chỉ những test đọc chúng từ đĩa |
| file khác trong `app_flutter/` mà không luật nào biết (`lib/x.json`, `Makefile`, `integration_test/…`) | **tất cả** |
| không đọc được git / không có base / lỗi cú pháp directive / test không có import nào / lỗi bất kỳ trong công cụ | **tất cả** |
| không test nào bị ảnh hưởng (chỉ đổi docs, …) | **không test** (`--on-none=skip`), báo rõ trong log và summary; `--on-none=all` để chạy tất cả |

## Trong CI

`.github/workflows/flutter.yml`, job `affected`:

- `push` (flutter-rewrite, develop, main): luôn chạy tất cả, không phân tích.
- `pull_request`: cài Flutter bằng cùng `subosito/flutter-action` (có cache) như các job khác, rồi chạy `dart --packages=<rỗng> tool/affected_test.dart <base.sha> --github-output --verbose`. Công cụ chỉ import thư viện `dart:` nên không cần `pub get`; phân tích mất khoảng 1 giây. Công cụ lỗi thì bước này ghi `scope=ALL`.
- Output `scope` (`ALL`/`AFFECTED`/`NONE`) và `files` được 4 shard của job `test` dùng như trước: `ALL` chạy `flutter test --total-shards=4`, `AFFECTED` chia đều danh sách file cho 4 shard, `NONE` bỏ qua job `test` (cảnh báo `::warning` và step summary ghi rõ lý do).
- Biến repo `AFFECTED_ON_NONE=all` (Settings → Variables) đổi hành vi khi không có test bị ảnh hưởng thành chạy tất cả.
- Bộ lọc `pull_request.paths` của workflow phải chứa mọi file ngoài `app_flutter/` mà test đọc, nếu không thì PR chỉ đổi file đó sẽ không chạy workflow. `test/tool/affected/workflow_paths_test.dart` kiểm tra điều này.

## Mở rộng luật

Luật chung nằm trong `AffectedConfig` (`tool/affected/analysis.dart`); luật riêng của repo nằm ở hằng `config` trong `tool/affected_test.dart`:

- `globalFiles` (tính từ package) / `repoGlobalFiles` (tính từ repo): glob buộc chạy tất cả. Ví dụ thêm một bộ sinh mã đọc file ngoài package: thêm input của nó vào `repoGlobalFiles`.
- `platformFiles`, `passiveFiles`: những file chỉ test đọc từ đĩa mới thấy.
- `derivedDirs`: thư mục có file Dart sinh từ file không phải Dart bên cạnh (như `lib/l10n`).
- `generatedSuffixes`: hậu tố mã sinh.
- `sourceRoots`, `testRoot`, `testSuffix`, `testConfigFile`.

Glob dùng `*` (trong một đoạn) và `**` (mọi độ sâu). Thêm luật thì thêm test vào `test/tool/affected/analysis_test.dart`. Khi phân vân giữa "không test" và "tất cả", chọn "tất cả".

## Giới hạn đã biết

- Phụ thuộc chỉ qua directive và qua đường dẫn literal trong `File`/`Directory`/`Link`. Test đọc file theo cách khác (`File.fromUri`, `Process.run`, biến môi trường) thì công cụ không thấy; khi viết test kiểu đó, dùng `File('đường/dẫn')` để nó được chọn đúng.
- Asset nạp qua `rootBundle` không được nối từng file: mọi thay đổi trong `assets/` hay asset khai báo trong pubspec đều chạy tất cả.
- `package:` của package khác: thay đổi phải đi qua `pubspec.lock` (chạy tất cả); `path:` dependency đổi cũng chạy tất cả.
- Không cache đồ thị: dựng lại mỗi lần mất khoảng 0,2 giây cho ~470 file, ít hơn thời gian khởi động VM Dart, và CI luôn bắt đầu từ checkout sạch nên cache không giúp được gì.
- Golden test bị loại ở CI (`--exclude-tags golden`) nên một golden đổi chỉ được kiểm ở máy.
