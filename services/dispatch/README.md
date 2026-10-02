# dispatch-service (Chụp ngay)

Dịch vụ điều phối đặt nhiếp ảnh gia tức thì. Thiết kế: `docs/superpowers/specs/2026-10-01-instant-booking-design.md`.

- Hợp đồng: [`api/openapi.yaml`](api/openapi.yaml) (`/v1`), gồm cả dạng bản sao Firestore mà ứng dụng nghe realtime.
- Domain thuần (máy trạng thái, vòng mời, chấm điểm, tiền và huỷ): `packages/dispatch-core`.
- Hạ tầng: Redis (GEO vị trí đang sẵn sàng, khoá lời mời, hàng đợi hẹn giờ BullMQ), PostgreSQL + PostGIS (schema `dispatch`), FCM, Firestore (chỉ ghi bản sao).
- Kế hoạch: `docs/superpowers/plans/2026-10-01-instant-i2-dispatch-core.md` … `-i6-…`.
