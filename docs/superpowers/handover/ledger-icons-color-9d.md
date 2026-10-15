# Handover ledger — plan 9d (Material Symbols Rounded, 60‑30‑10 palette)

Plan: `docs/superpowers/plans/2026-10-06-icons-color-603010.md` (user decisions 2026-10-06: Rounded, "Trung tính + tím", mock + tokens + app).

## Built
- Tokens: dark CTA violet two-stop `#8A3FFC → #6E2FD6` (no `cta-mid`), `accent*` aliases of `primary`, semantic `verified` (blue `#3D63FF`), spectrum tokens documented as loader-only; `tokens.css` regenerated.
- Core `AppIcons` / `AppIcon` / `AppIconSize` on `material_symbols_icons` (Rounded, FILL 1 for selected); all `lib/` icons migrated; theme back/close buttons use `AppIcons`; lint tests: features use `AppIcons` only, spectrum only in loaders.
- Accent discipline in features (idle icons, pins, labels → neutral); AuroraHero/AuroraBackground/GlassCard off the spectrum.
- Mock: Material Symbols Rounded font, 304 icons converted (seal, Zalo, WhatsApp stay SVG), accent uses 97 → CTA/active/selected/links/progress only, violet CTA, no `--spec`. Gallery: "Icons" and "Màu · quy tắc 60-30-10" sections.
- Docs: main spec §1 (60‑30‑10, icon family), shared-components "Icons" table, CLAUDE.md rule line.

## Rulings
- Order 1 → 3+4 → 2+5 (bigger dispatches, user's request); mock/docs ran in parallel with the app review (disjoint files).
- The blue verified tick is a semantic mark with its own `verified` token, exempt like gold and status colours.
- Initials avatar tint is neutral (onSurface 12 %).
- photo_detail `_ServiceCard` has no accent border: `active` means "still offered"; inactive shows by opacity + the red line.
- Brand logo ring keeps spectrum + cyan (second exception besides loaders).

## Deferred
- `AppIcon` optical size fixed at 24 for all sizes (matches the mock CSS).
- `AppIconSize` adoption: many call sites still pass raw sizes (10–18).
- Formatter churn in a few touched files (chat_screen, service_step, badge_*, notification_row).
- Light `foregroundMuted` #898888 is below 4.5:1 for small text on white/canvas (pre-existing token); `context.mutedForeground` is for idle glyphs only. Follow-up: darken the light token.
- `ColorScheme.onSurfaceVariant` keeps the Material default (mapping it to the muted token dimmed field labels, list subtitles and banners app-wide).
