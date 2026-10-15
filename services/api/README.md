# api (self-hosted backend, phase 2)

First vertical slice of the self-hosted backend described in
`docs/superpowers/specs/data-model/`. Plan: `docs/superpowers/plans/2026-10-01-backend-phase2-selfhosted-postgres.md`.
Contract: [`api/openapi.yaml`](api/openapi.yaml).

```bash
cd services/api
cp .env.example .env               # optional, defaults work
docker compose up --build -d       # db + migrate + api on :8787
curl -s localhost:8787/v1/health   # {"status":"ok","db":"ok"}
docker compose --profile tools up -d adminer   # http://localhost:8081 (server db, user nag)
docker compose down                # keep data; add -v to drop the volume

npm ci && npm test                 # needs Docker (Testcontainers)
```

Run the app against it: `flutter run --dart-define=BACKEND=selfhosted --dart-define=BASE_URL=http://10.0.2.2:8787`
(Android emulator; iOS simulator: `http://localhost:8787`). The app signs in with the real Firebase
project, so start the API with `AUTH_MODE=firebase` and that project's `FIREBASE_PROJECT_ID`.
