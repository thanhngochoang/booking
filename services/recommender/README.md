# recommender-service

Dịch vụ gợi ý chạy riêng của app Cộng đồng nhiếp ảnh gia. Thiết kế đầy đủ ở `docs/superpowers/specs/2026-10-01-remaining-screens.md` mục 3e. Thư mục này hiện chỉ có **hợp đồng API**; chưa có mã chạy.

## Vì sao tách riêng

Thuật toán gợi ý sẽ đổi nhiều lần (luật → học xếp hạng → nhúng ảnh). Tách thành dịch vụ có hợp đồng cố định để nâng cấp mà không phát hành lại ứng dụng.

## Kiến trúc

```
Ứng dụng ──callable `recommend` (Auth + App Check + giới hạn tần suất)──▶ recommender-service (Cloud Run, riêng tư)
                                                                            │ đọc: photographers, availability, events, stats
                                                                            └ ghi: recommendation_logs
```

- Hợp đồng: [`api/openapi.yaml`](api/openapi.yaml), phiên bản đường dẫn `/v1`. Ứng dụng và Functions sinh kiểu dữ liệu từ tệp này.
- Dịch vụ không mở công khai; chỉ tài khoản dịch vụ của hàm `recommend` được gọi.
- Vị trí chỉ là `geohash6`, không có toạ độ. Mã người dùng là `userKey` đã băm.

## Có cần dịch vụ riêng ngay không?

**Chưa.** v1 là luật có trọng số trên vài trăm ứng viên đã lọc theo khu vực và ngày, nên chạy được trong hàm Cloud Functions `recommend`. Vì vậy:

1. **Giai đoạn 1 (ra mắt)**: viết `packages/recommender-core` (TypeScript thuần, không `import` Firebase) gồm `Scorer`, bộ lọc, MMR, sinh lý do. Hàm `recommend` gọi gói này; ứng dụng có `LocalRecommender` dự phòng. Không dựng Cloud Run.
2. **Giai đoạn 2**: bọc đúng gói đó thành dịch vụ ở thư mục này (Cloud Run) khi chạm một trong các ngưỡng: ≥ 5.000 nhiếp ảnh gia hoạt động; p95 > 400 ms; cần tính đặc trưng/mô hình ngoại tuyến; có client thứ hai.

Hợp đồng `api/openapi.yaml` và giao diện `RecommendationRepository` không đổi giữa hai giai đoạn, nên nâng cấp không động tới ứng dụng. Chuyển sang *ghép cặp tự động* (điều phối yêu cầu tới nhiều nhiếp ảnh gia) là sản phẩm khác, ngoài phạm vi v1.

## Bộ xếp hạng cắm được

Mỗi thuật toán là một `Scorer` đăng ký theo tên:

| Tên | Trạng thái | Ghi chú |
|-----|-----------|---------|
| `rules-v1` | Kế hoạch | Luật có trọng số, giải thích được (spec mục 3e.6) |
| `ltr-v2` | Ý tưởng | Học xếp hạng từ `recommendation_logs`, nhúng ảnh portfolio |

- `algorithm` trong yêu cầu chọn bản; bỏ trống dùng bản mặc định trong cấu hình (`config/recommender`).
- Trọng số và ngưỡng nằm trong cấu hình, không nằm trong mã.
- Thêm thuật toán mới: viết `Scorer`, đăng ký, chạy **shadow** (tính nhưng không hiển thị, so sánh), rồi A/B 10% → 50% → 100%. Quay lại bằng cấu hình.

## Dự phòng

Ứng dụng có `LocalRecommender` (sao đã làm mượt + khoảng cách). Dịch vụ lỗi hoặc quá 800 ms thì ứng dụng dùng nó, nên dịch vụ chết không làm hỏng Tìm thợ ảnh.

## Việc cần làm khi bắt đầu viết mã

1. Chọn ngôn ngữ (đề xuất TypeScript để dùng chung kiểu với Cloud Functions).
2. Sinh kiểu từ `openapi.yaml`; thêm test hợp đồng chạy cho cả `RemoteRecommendationRepository` và `LocalRecommender` trong ứng dụng.
3. Cài `rules-v1` theo spec; tập dữ liệu mẫu để test thứ tự và lý do.
4. Triển khai Cloud Run, IAM, `recommend` callable, `recommendFeedback`.
