# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Cộng đồng nhiếp ảnh gia" (applicationId `com.thanhbk.timnhay`) is a native Android app (Java, 2017) for booking photographers. Two roles share one app: customers find/book photographers and post open projects; photographers manage albums, accept/deny bookings and attend open projects. Both roles can chat 1‑1. There is no custom backend: everything goes through Firebase (Auth via Facebook/Google, Firestore, Realtime Database, Storage).

UI strings are Vietnamese. Java package is `com.paditech.mvpbase` (the app was scaffolded from a Paditech MVP template; `APIService`/`APIClient` and `FlickrManager` are leftover template code, not used by the core flows).

## Build / test

Legacy toolchain: Gradle 4.1 wrapper, Android Gradle Plugin 3.0.1, compileSdk 26, pre‑AndroidX Support Library, deprecated `compile` dependency syntax. It requires an old JDK (8) and Android Studio 3.x; expect it not to build with a current Android Studio/JDK without a full upgrade.

```bash
./gradlew assembleEnvTestDebug          # build debug APK (flavors: envReal, envTest)
./gradlew assembleEnvRealRelease
./gradlew installEnvTestDebug           # install on connected device
./gradlew testEnvTestDebugUnitTest      # JVM unit tests
./gradlew testEnvTestDebugUnitTest --tests com.paditech.mvpbase.ExampleUnitTest
./gradlew connectedEnvTestDebugAndroidTest   # instrumented tests (device required)
```

The two flavors are identical: both `Config.java` files (`app/src/envReal`, `app/src/envTest`) are empty and both use the same applicationId. Only the default example tests exist.

## Architecture

### Custom MVP framework (`common/mvp`)
Every screen is a triple in `screen/<name>/`:
- `XxxContact` — two nested interfaces: `ViewOps` (what the presenter can call on the view) and `PresenterViewOps` (what the view can call on the presenter).
- `XxxPresenter` — extends `FragmentPresenter<ViewOps>` or `ActivityPresenter<ViewOps>`; does all Firebase calls and reports back via `getView()`.
- `XxxFragment` / `XxxActivity` — extends `MVPFragment<PresenterViewOps>` / `MVPActivity<...>`, returns the presenter class from `onRegisterPresenter()`, uses ButterKnife for views, and accesses the presenter via `mPresenter`.

Presenters are instantiated by reflection through the `PresenterFactory` singleton, keyed by the view class's simple name, so a presenter needs a public no‑arg constructor. Progress/error dialogs are delegated from fragments to the host `MVPActivity`.

### Navigation
`LoginActivity` is the launcher. After login, `MainActivity` hosts all feature screens as fragments via `replaceFragment(...)`, driven by a navigation drawer whose items come from `MenuType.UserMenu` or `MenuType.PhotographerMenu` depending on `User.is_photographer`. Only a few flows (register, terms, update profile, full‑screen image view, multi‑image picker) are separate activities.

### Data flow
- **Firestore collections**: `users` (doc id = Firebase Auth uid), `booking`, `albums`, `chat_room`, `photographers_attended`. Models in `common/model` expose `getMaps()` for writes; fields not stored are marked `@Exclude`.
- **Realtime Database**: `chat_room/<id>/messages`, `user_devices`.
- **Storage**: `albums/`, `avatars/`, `image/` (chat images). Album uploads run in `UploadFileService` (an `IntentService`) and finish with an `UploadAlbumSuccess` EventBus event.
- **Realm** (`timnhay.realm`) is a local cache for `Booking` and `ChatRoom` only. `BaseApplication` attaches Firestore snapshot listeners once a user is authenticated, writes results into Realm, then posts `OnUpdateCalendarEvent` / `OnUpdateMessagesEvent` on EventBus. Screens such as Calendar and List Messenger read from Realm and refresh on those events rather than querying Firestore themselves. Realm models (`Booking`, `ChatRoom`) mark non‑persisted fields with `@Ignore` in addition to `@Exclude`.
- Booking lifecycle is the int `status` field mapped by `BookStatus` (WAITING=0, ACCEPTED=1, DENIED=2, OPENED=3, CLOSED=4); `Booking.is_photographer_project` distinguishes direct bookings from open projects that photographers attend. Price buckets for search live in `PriceEnum`.
- Current uid and login state come from `PrefUtil` (wraps Firebase Auth + SharedPreferences).

### Other notable pieces
- Date/time display formats are centralised in `common/utils/Constant.java`.
- Calendar screen uses `android-week-view` and can sync to Google Calendar via the Google Calendar API (`google_calendar_account` on `User`).
- Registration terms are the static HTML asset `app/src/main/assets/list_terms.html`.
