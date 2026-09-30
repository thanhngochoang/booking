# Graph Report - booking  (2026-09-30)

## Corpus Check
- 184 files · ~57,245 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 135 file(s) not represented in the graph (top: .xml 128, (none) 2, .properties 2)

## Summary
- 2109 nodes · 5415 edges · 143 communities (75 shown, 68 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 401 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Legacy REST APIClient
- Date/Time Picker Dialogs
- Bottom Dialog Base
- Image Collage & Multi-Select
- Fragment View Contracts
- Load-More RecyclerView
- Screen Fragments & Menu
- Profile Comments Adapter
- Fade Toolbar ScrollView
- Booking Model & Contract
- Chat Room Model
- Update Profile Imports
- Google Calendar AsyncTask
- Presenters & Firestore Albums
- CommonUtil Helpers
- Badge Drawer Arrow
- Gradle Dependencies
- Chat Message Contract
- Fragment Presenters
- Auth Providers & Device
- Image Picker Manager
- MVP Activity Base
- MVP Fragment Base
- Album Upload Service
- Photo Grid Adapter
- Domain Models & Firestore
- Booking Status Lifecycle
- User Model Setters
- Login Presenter
- Calendar Fragment
- Main Activity Drawer
- Message & Image Dialogs
- Message List Screen
- Presenter Base Contracts
- Login/Register Activities
- Base Fragment
- Base Activity & Toast
- My Project Pager
- Add Image Adapter
- Chat Room Lookup
- Activity View Contracts
- String & Price Utils
- Device & File Managers
- Gallery Adapter
- Create Album Screen
- Find Project Screen
- Menu Adapter
- Location Manager APIs
- Test Scaffolding
- Toolchain env.sh
- Chat Message Adapter
- Media Picker Presenter
- Design Token System
- Non-Swipeable ViewPager
- App Snapshot Listeners
- Manifest Components
- Price Range Enum
- Album Model
- Register/Profile Contracts
- Book Fragment
- My Project Adapter
- View Image Screen
- Custom Views & Progress
- Activity Presenter Base
- Get File Manager
- Location Manager
- Album Fragment
- Quick Image Adapter
- Home Fragment
- WebView Activity
- Base Activity Lifecycle
- Find Photographer Screen
- Photographer Adapter
- Messenger List Adapter
- Photographer Menu
- List Booking Fragment
- Date Picker Dialog
- Confirm Dialog Listeners
- Multi-Select Options
- Select Item Dialog
- Demo Image Adapter
- Login Contract
- Main Badge Contract
- User Menu
- Date Strip Adapter
- Manifest Permissions
- Enter Price Dialog
- Toast Popup Types
- Create Project Fragment
- Modernization Roadmap
- Android SDK Install
- Application Imports
- Calendar/Message Events
- User Info Listener
- Date Snap Helper
- Attendee List Adapter
- Animation Utils
- Gradle Plugins
- Jetifier & JitPack
- Time Picker Listener
- Rate Model
- Architecture Dead Ends
- Firebase Backend Overview
- JDK 17 & TLS Rationale
- MVP Framework Review
- Album Contract
- Book View Ops
- Home Contract
- Chat Bubble Tails
- Proposed Architecture
- Product Flavors
- Presenter Factory
- Price EditText
- Background Photos
- Launcher Icon
- Back Arrow Icon
- Rating Star Icons
- Security & Config Keys
- Config envReal
- Config envTest
- Project Adapter (unused)
- Project Contract (unused)
- Project Presenter (unused)
- Done Checkmark Icon
- Google Calendar Logo
- Flickr Logo
- Empty State Icon
- Facebook Icon
- Settings Gear Icon
- Google Login Icon
- Lens Attribute Icon
- Price Attribute Icon
- Style Attribute Icon
- Camera Body Icon
- Dark Mode Tokens
- Ops Track

## God Nodes (most connected - your core abstractions)
1. `User` - 84 edges
2. `Booking` - 80 edges
3. `FragmentPresenter` - 63 edges
4. `MVPFragment` - 62 edges
5. `BookFragment` - 54 edges
6. `MainActivity` - 53 edges
7. `MVPActivity` - 51 edges
8. `CreateProjectFragment` - 49 edges
9. `ChatRoom` - 46 edges
10. `FragmentViewOps` - 43 edges

## Surprising Connections (you probably didn't know these)
- `MVVM + UDF` --semantically_similar_to--> `Custom MVP framework (Contact/Presenter/Fragment)`  [INFERRED] [semantically similar]
  docs/MODERNIZATION-REVIEW.md → CLAUDE.md
- `Phase 0 library upgrade (done)` --semantically_similar_to--> `Upgrade 2017 to 2026`  [INFERRED] [semantically similar]
  docs/MODERNIZATION-REVIEW.md → README.md
- `Registration terms (static HTML, placeholder Dieu 1-5)` --conceptually_related_to--> `Custom MVP framework (Contact/Presenter/Fragment)`  [AMBIGUOUS]
  app/src/main/assets/list_terms.html → CLAUDE.md
- `Security and ops issues` --semantically_similar_to--> `Committed API keys issue`  [INFERRED] [semantically similar]
  docs/MODERNIZATION-REVIEW.md → README.md
- `Rationale: no Java 21+ before AGP change` --semantically_similar_to--> `Rationale: JDK 17 not newer`  [INFERRED] [semantically similar]
  docs/MODERNIZATION-REVIEW.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **MVP base contract** — app_src_main_java_com_paditech_mvpbase_common_mvp_basepresenter, app_src_main_java_com_paditech_mvpbase_common_mvp_baseviewops, app_src_main_java_com_paditech_mvpbase_common_mvp_basepresenterops, app_src_main_java_com_paditech_mvpbase_common_mvp_presenterviewops, app_src_main_java_com_paditech_mvpbase_common_mvp_presenterfactory [EXTRACTED 0.90]
- **Dialogs built on BaseDialog** — app_src_main_java_com_paditech_mvpbase_common_base_basedialog, app_src_main_java_com_paditech_mvpbase_common_dialog_enterpricedialog, app_src_main_java_com_paditech_mvpbase_common_dialog_loadingdialog, app_src_main_java_com_paditech_mvpbase_common_dialog_messagedialog [EXTRACTED 0.95]
- **Photographer profile attribute icons** — app_src_main_res_drawable_xxxhdpi_ic_lens, app_src_main_res_drawable_xxxhdpi_ic_thanmay, app_src_main_res_drawable_xxxhdpi_ic_price, app_src_main_res_drawable_xxxhdpi_ic_style [INFERRED 0.80]
- **EventBus UI update events** — app_src_main_java_com_paditech_mvpbase_common_event_onupdatemessagesevent, app_src_main_java_com_paditech_mvpbase_common_event_onupdatecalendarevent, app_src_main_java_com_paditech_mvpbase_common_event_uploadalbumsuccess, app_src_main_java_com_paditech_mvpbase_baseapplication_baseapplication, app_src_main_java_com_paditech_mvpbase_common_service_upload_file_uploadfileservice [INFERRED 0.75]
- **Firebase data sources mapped by FirebaseHelper** — app_src_main_java_com_paditech_mvpbase_common_firebase_firebasehelper_firebasehelper, firestore_users, firestore_booking, rtdb_chat_room [EXTRACTED 0.90]
- **Permission+ActivityResult helper managers (image, file, location)** — app_src_main_java_com_paditech_mvpbase_common_utils_get_image_getimagemanager, app_src_main_java_com_paditech_mvpbase_common_utils_get_file_getfilemanager, app_src_main_java_com_paditech_mvpbase_common_utils_get_location_getlocationmanager [INFERRED 0.80]
- **SelectMulti MVP triad** — app_src_main_java_com_paditech_mvpbase_common_utils_get_image_selectmultiactivity, app_src_main_java_com_paditech_mvpbase_common_utils_get_image_selectmultipresenter, app_src_main_java_com_paditech_mvpbase_common_utils_get_image_selectmulticontact [EXTRACTED 1.00]
- **Image picking pipeline** — app_src_main_java_com_paditech_mvpbase_common_utils_get_image_getimagemanager, app_src_main_java_com_paditech_mvpbase_common_utils_get_image_selectmultiactivity, app_src_main_java_com_paditech_mvpbase_common_utils_imageutil, ext_mediastore [INFERRED 0.80]
- **Login and onboarding flow** — app_src_main_java_com_paditech_mvpbase_screen_login_loginactivity_loginactivity, app_src_main_java_com_paditech_mvpbase_screen_login_loginpresenter_loginpresenter, auth_google, auth_facebook, firestore_users, app_src_main_java_com_paditech_mvpbase_screen_main_mainactivity_mainactivity [EXTRACTED 0.85]
- **Photographer registration flow** — app_src_main_java_com_paditech_mvpbase_screen_register_registeractivity_registeractivity, app_src_main_java_com_paditech_mvpbase_screen_term_register_ternregisteractivity_ternregisteractivity, app_src_main_java_com_paditech_mvpbase_screen_update_profile_updateprofileactivity_updateprofileactivity, app_src_main_java_com_paditech_mvpbase_screen_main_mainactivity_mainactivity [EXTRACTED 0.85]
- **Booking lifecycle: find, book, accept/deny** — app_src_main_java_com_paditech_mvpbase_screen_find_photographer_findphotographerfragment, app_src_main_java_com_paditech_mvpbase_screen_book_bookfragment, app_src_main_java_com_paditech_mvpbase_screen_book_bookpresenter, col_booking, st_accepted, st_denied [INFERRED 0.85]
- **Open project flow: create, discover, join, close** — app_src_main_java_com_paditech_mvpbase_screen_create_project_createprojectpresenter, app_src_main_java_com_paditech_mvpbase_screen_find_project_findprojectpresenter, col_attended, st_opened, st_closed, app_src_main_java_com_paditech_mvpbase_screen_my_project_myprojectadapter [INFERRED 0.80]
- **Chat room discovery, creation and messaging flow** — app_src_main_java_com_paditech_mvpbase_screen_messenger_messengerpresenter_messengerpresenter, app_src_main_java_com_paditech_mvpbase_screen_messenger_messengerpresenter_firestore_chat_room, app_src_main_java_com_paditech_mvpbase_screen_messenger_messengerpresenter_rtdb_chat_room_messages, app_src_main_java_com_paditech_mvpbase_screen_messenger_messengerpresenter_firebase_storage_image, app_src_main_java_com_paditech_mvpbase_screen_list_messenger_listmessengerpresenter_realm_chatroom [INFERRED 0.85]
- **Album creation and upload flow** — app_src_main_java_com_paditech_mvpbase_screen_create_album_createalbumfragment_createalbumfragment, app_src_main_java_com_paditech_mvpbase_screen_create_album_addimageadapter_addimageadapter, uploadfileservice_uploadfileservice, app_src_main_java_com_paditech_mvpbase_screen_create_album_createalbumfragment_uploadalbumsuccess_event, app_src_main_java_com_paditech_mvpbase_screen_album_albumpresenter_firestore_albums [INFERRED 0.80]
- **Firebase artifacts managed by BoM** — app_build_firebase_bom, app_build_firebase_auth, app_build_firebase_firestore, app_build_firebase_database, app_build_firebase_storage, app_build_firebase_messaging, app_build_firebase_analytics [EXTRACTED 1.00]
- **Corporate TLS workaround toolchain** — scripts_env_truststore, scripts_env_cloudflare_gateway, scripts_env_gradle_daemon_props, scripts_env_truststore_rationale [INFERRED 0.85]
- **Project-local SDK/JDK setup** — scripts_env, scripts_install_sdk, scripts_env_local_sdk, scripts_env_local_jdk17 [INFERRED 0.85]
- **Modernization roadmap phases 0-4** — mr_phase0, mr_phase1, mr_phase2, mr_phase3, mr_phase4 [EXTRACTED 0.95]
- **Design token three layers** — ds_primitive, ds_semantic, ds_component [EXTRACTED 0.95]
- **Build toolchain constraints** — readme_jdk17, readme_agp85, readme_truststore, readme_cloudflare_gateway [INFERRED 0.80]
- **White flat glyph icons for tinted surfaces** — app_src_main_res_drawable_xxhdpi_icon_back_white_topbar, app_src_main_res_drawable_xxxhdpi_ic_empty, app_src_main_res_drawable_xxxhdpi_ic_fb, app_src_main_res_drawable_xxxhdpi_ic_gear_other [INFERRED 0.75]
- **Third-party brand logos** — app_src_main_res_drawable_xxhdpi_logo_calender, app_src_main_res_drawable_xxhdpi_logo_flirk [INFERRED 0.80]
- **Star rating states** — app_src_main_res_drawable_xxhdpi_icon_star_1, app_src_main_res_drawable_xxhdpi_icon_star_2 [EXTRACTED 0.95]

## Communities (143 total, 68 thin omitted)

### Community 0 - "Legacy REST APIClient"
Cohesion: 0.06
Nodes (9): APIClient, APIClient, APIService, APIService, ICallBack, ICallBack, BaseResponse, BaseResponse (+1 more)

### Community 1 - "Date/Time Picker Dialogs"
Cohesion: 0.07
Nodes (16): DatePickerDialog, SelectItemDialog, TimePickerDialog, TimePickerDialog, Constant, Constant, PlacePickerHelper, PlacePickerHelper (+8 more)

### Community 2 - "Bottom Dialog Base"
Cohesion: 0.10
Nodes (17): BaseBottomDialog, BaseBottomDialog, BaseDialog, BaseDialog, BaseFragment, EnterPriceDialog, LoadingDialog, LoadingDialog (+9 more)

### Community 3 - "Image Collage & Multi-Select"
Cohesion: 0.13
Nodes (13): SelectMultiActivity, ImageUtil, ImageUtil, AutoTopImageLayout, AutoTopImageLayout, ImagerQuickAdapter, PhotographerAdapter, GalleryHolder (+5 more)

### Community 4 - "Fragment View Contracts"
Cohesion: 0.06
Nodes (16): FragmentPresenterViewOps, FragmentViewOps, CalendarContact, PresenterViewOps, ViewOps, CreateAlbumContact, PresenterViewOps, ViewOps (+8 more)

### Community 5 - "Load-More RecyclerView"
Cohesion: 0.10
Nodes (5): DataObserver, LoadMoreListener, LoadMoreRecyclerView, SimpleViewHolder, WrapAdapter

### Community 6 - "Screen Fragments & Menu"
Cohesion: 0.13
Nodes (8): FindProjectFragment, MenuType, MessengerFragment, ListBookingFragment, MyProjectFragment, ProjectFragment, ProjectFragment, TernRegisterActivity

### Community 7 - "Profile Comments Adapter"
Cohesion: 0.09
Nodes (9): Comment, ProfileAdapter, ProfileHolder, RatingHolder, PresenterViewOps, ProfileContact, ViewOps, ProfileFragment (+1 more)

### Community 8 - "Fade Toolbar ScrollView"
Cohesion: 0.10
Nodes (9): FadeToolbarScrollView, FadeToolbarScrollView, ObservableScrollViewCallbacks, SavedState, ScrollState, DOWN, UP, TextViewLinkHandler (+1 more)

### Community 9 - "Booking Model & Contract"
Cohesion: 0.10
Nodes (7): Booking, BookContact, PresenterViewOps, BookPresenter, PresenterViewOps, CreateProjectPresenter, ViewOps

### Community 10 - "Chat Room Model"
Cohesion: 0.11
Nodes (3): GetTimeAndMessageChatRoomListener, GetTimeAndMessageChatRoomListener, ChatRoom

### Community 13 - "Presenters & Firestore Albums"
Cohesion: 0.21
Nodes (17): Album, PrefUtil, PrefUtil, BookPresenter, CreateProjectPresenter, FindPhotographerPresenter, FindProjectPresenter, ListBookingPresenter (+9 more)

### Community 15 - "Badge Drawer Arrow"
Cohesion: 0.09
Nodes (4): BadgeDrawerArrowDrawable, BadgeDrawerArrowDrawable, SimpleDividerItemDecoration, SimpleDividerItemDecoration

### Community 16 - "Gradle Dependencies"
Cohesion: 0.10
Nodes (29): AndroidX libs (appcompat, recyclerview, cardview, etc.), app module build.gradle, applicationId com.thanhbk.timnhay, ButterKnife 10.2.3, ButterKnife compiler, CircleImageView 3.1.0, EventBus 3.3.1, firebase-analytics (+21 more)

### Community 17 - "Chat Message Contract"
Cohesion: 0.09
Nodes (5): Message, MessengerContact, PresenterViewOps, ViewOps, MessengerFragment

### Community 18 - "Fragment Presenters"
Cohesion: 0.08
Nodes (9): FragmentPresenter, AlbumPresenter, CalendarPresenter, Realm cached Booking records, FindPhotographerPresenter, FindProjectPresenter, ListMessengerPresenter, Realm cached ChatRoom records (+1 more)

### Community 20 - "Image Picker Manager"
Cohesion: 0.15
Nodes (3): SelectImageDialogListenner, GetImageManager, OnGetImageListener

### Community 23 - "Album Upload Service"
Cohesion: 0.10
Nodes (7): UploadAlbumSuccess, UploadAlbumSuccess, UploadFileService, UploadFileService, HomePresenter, Firestore collection: albums, Storage path: albums/{uid}/

### Community 24 - "Photo Grid Adapter"
Cohesion: 0.15
Nodes (3): GridPhotoAdapter, ImageHolder, SelectMultiActivity

### Community 25 - "Domain Models & Firestore"
Cohesion: 0.14
Nodes (15): FirebaseHelper, Booking, BookStatus, ChatRoom, Comment, Message, Rate, User (+7 more)

### Community 26 - "Booking Status Lifecycle"
Cohesion: 0.10
Nodes (7): GetListAttendListener, BookStatus, ACCEPTED, CLOSED, DENIED, OPENED, WAITING

### Community 28 - "Login Presenter"
Cohesion: 0.17
Nodes (5): LoginPresenter, RegisterPresenter, Facebook auth, Google Sign-In auth, Realtime DB: user_devices

### Community 31 - "Message & Image Dialogs"
Cohesion: 0.16
Nodes (3): MessageDialog, MessageDialog, SelectImageDialog

### Community 32 - "Message List Screen"
Cohesion: 0.15
Nodes (6): OnUpdateMessagesEvent, OnUpdateMessagesEvent, ListMessengerContact, PresenterViewOps, ViewOps, ListMessengerFragment

### Community 33 - "Presenter Base Contracts"
Cohesion: 0.17
Nodes (11): ActivityPresenter, ActivityPresenterViewOps, BasePresenter, BasePresenter, BasePresenterOps, BasePresenterOps, BaseViewOps, FragmentPresenter (+3 more)

### Community 36 - "Base Activity & Toast"
Cohesion: 0.14
Nodes (5): BaseActivity, ToastPopup, ToastPopup, OnReloadListener, OnReloadListener

### Community 37 - "My Project Pager"
Cohesion: 0.16
Nodes (7): MyProjectContact, PresenterViewOps, ViewOps, BookPageAdapter, MyProjectFragment, MyProjectPresenter, MyProjectPresenter

### Community 39 - "Add Image Adapter"
Cohesion: 0.18
Nodes (4): AddImageAdapter, AddImageHolder, OnAddImageListener, PhotoHolder

### Community 40 - "Chat Room Lookup"
Cohesion: 0.20
Nodes (6): CreateRoomListener, findRoom / createRoom logic, FindRoomListener, Firestore chat_room collection, MessengerPresenter, Realtime Database chat_room/{id}/messages

### Community 41 - "Activity View Contracts"
Cohesion: 0.12
Nodes (4): ActivityViewOps, TernRegisterContact, ViewOps, ViewOps

### Community 43 - "Device & File Managers"
Cohesion: 0.19
Nodes (4): Device, GetFileManager, GetImageManager, Repositories google/mavenCentral/gradlePluginPortal

### Community 44 - "Gallery Adapter"
Cohesion: 0.18
Nodes (3): GalleryAdapter, ItemGalleryClickListener, OnViewImageListener

### Community 45 - "Create Album Screen"
Cohesion: 0.20
Nodes (5): Firestore albums collection, CreateAlbumFragment, UploadAlbumSuccess event handler, Firebase Storage image/ (chat images), UploadFileService

### Community 46 - "Find Project Screen"
Cohesion: 0.17
Nodes (4): FindProjectContact, PresenterViewOps, ViewOps, FindProjectFragment

### Community 47 - "Menu Adapter"
Cohesion: 0.19
Nodes (3): MenuAdapter, MenuHolder, OnMenuSelectListener

### Community 49 - "Test Scaffolding"
Cohesion: 0.18
Nodes (5): AndroidX Test / Espresso, JUnit 4.13.2, namespace com.paditech.mvpbase, ExampleInstrumentedTest, ExampleUnitTest

### Community 50 - "Toolchain env.sh"
Cohesion: 0.14
Nodes (14): Java/JDK 17 compatibility, ANDROID_HOME, ANDROID_SDK_ROOT, Cloudflare Zero Trust TLS gateway, Rationale: Gradle daemon does not inherit GRADLE_OPTS, ~/.gradle/gradle.properties truststore registration, GRADLE_OPTS, Project-local JDK 17 (.jdk / Homebrew fallback) (+6 more)

### Community 51 - "Chat Message Adapter"
Cohesion: 0.26
Nodes (3): ChatMeHolder, ChatYouHolder, MessageAdapter

### Community 52 - "Media Picker Presenter"
Cohesion: 0.17
Nodes (7): SelectMultiContact, PresenterViewOps, SelectMultiContact, ViewOps, SelectMultiPresenter, SelectMultiPresenter, Android MediaStore / FileProvider camera

### Community 53 - "Design Token System"
Cohesion: 0.14
Nodes (15): Component layer, Component specs (button, chip, badge...), WCAG AA contrast, Token naming conventions, Legacy resource migration table, Primitive layer, Semantic layer, 4dp spacing grid (+7 more)

### Community 54 - "Non-Swipeable ViewPager"
Cohesion: 0.21
Nodes (3): NonSwipeableViewPager, MyScroller, NonSwipeableViewPager

### Community 56 - "Manifest Components"
Cohesion: 0.15
Nodes (14): Facebook Login SDK 17.0.0, Google Places SDK 3.5.0, BaseApplication (application class), LoginActivity (launcher), MainActivity, meta-data facebook ApplicationId, meta-data facebook ClientToken, meta-data Google geo API_KEY (+6 more)

### Community 57 - "Price Range Enum"
Cohesion: 0.15
Nodes (8): OnSelectRangePriceListener, PriceEnum, PriceEnum, PRICE_1, PRICE_2, PRICE_3, PRICE_4, PRICE_5

### Community 59 - "Register/Profile Contracts"
Cohesion: 0.16
Nodes (6): ActivityPresenterViewOps, PresenterViewOps, RegisterContact, ViewOps, PresenterViewOps, UpdateProfileContact

### Community 61 - "My Project Adapter"
Cohesion: 0.23
Nodes (3): MyProjectAdapter, MyProjectHolder, OnItemBookClickListener

### Community 62 - "View Image Screen"
Cohesion: 0.20
Nodes (5): ViewImageActivity, PresenterViewOps, ViewImageContact, ViewOps, ViewImagePresenter

### Community 63 - "Custom Views & Progress"
Cohesion: 0.21
Nodes (3): ValueProgressBar, ProgressBarListener, ValueProgressBar

### Community 65 - "Activity Presenter Base"
Cohesion: 0.21
Nodes (3): ActivityPresenter, PresenterViewOps, TernRegisterPresenter

### Community 69 - "Quick Image Adapter"
Cohesion: 0.24
Nodes (3): ImageHolder, ImagerQuickAdapter, OnViewImageListener

### Community 76 - "Photographer Menu"
Cohesion: 0.17
Nodes (11): PhotographerMenu, ABOUT, AlBUMS, CALENDAR, FIND_PROJECT, HELP, LOGOUT, MESSAGES (+3 more)

### Community 80 - "Multi-Select Options"
Cohesion: 0.22
Nodes (4): OnGetListPhotoSelectListener, SelectType, MULTIPLE, SINGLE

### Community 81 - "Select Item Dialog"
Cohesion: 0.36
Nodes (3): SelectItemDialog, TextAdapter, TextHolder

### Community 83 - "Login Contract"
Cohesion: 0.18
Nodes (3): LoginContact, PresenterViewOps, ViewOps

### Community 84 - "Main Badge Contract"
Cohesion: 0.22
Nodes (5): MainContact, PresenterViewOps, ViewOps, MainPresenter, Realm ChatRoom/Booking unread counts

### Community 85 - "User Menu"
Cohesion: 0.18
Nodes (10): UserMenu, ABOUT, BECOME_PHOTOGRAPHER, CALENDAR, HELP, LOGOUT, MESSAGES, MY_PROJECT (+2 more)

### Community 87 - "Manifest Permissions"
Cohesion: 0.20
Nodes (9): OkHttp 4.12.0, play-services-auth 21.2.0, play-services-location 21.3.0, Permission ACCESS_COARSE_LOCATION, Permission ACCESS_FINE_LOCATION, Permission CAMERA, Permission GET_ACCOUNTS, Permission INTERNET (+1 more)

### Community 89 - "Toast Popup Types"
Cohesion: 0.31
Nodes (3): ToastType, ALERT, ERROR

### Community 92 - "Modernization Roadmap"
Cohesion: 0.20
Nodes (10): envReal/envTest flavors, Legacy toolchain (Gradle 4.1/AGP 3.0.1), Things not to do, Phase 0 library upgrade (done), Modernization roadmap, AGP 8.5.2 / Gradle 8.9, AndroidX migration, Places SDK replaces Place Picker (+2 more)

### Community 93 - "Android SDK Install"
Cohesion: 0.22
Nodes (8): compileSdk/targetSdk 34, minSdk 23, local.properties sdk.dir, build-tools 34.0.0, dl.google.com direct download, SDK platform android-34, platform-tools, Rationale: direct zip download works where sdkmanager cannot reach network, install-sdk.sh script

### Community 101 - "Gradle Plugins"
Cohesion: 0.25
Nodes (6): realm-android plugin (sync disabled), Android Gradle Plugin 8.5.2, Google Services Gradle Plugin 4.4.2, Realm Gradle Plugin 10.19.0, Rationale: Realm ships as legacy buildscript plugin, Root build.gradle

### Community 102 - "Jetifier & JitPack"
Cohesion: 0.29
Nodes (7): android-week-view 1.2.6, android.useAndroidX, Jetifier enabled, Rationale: Jetifier needed for week-view Support Library binary, Gradle parallel and build caching, JitPack Maven repository, Rationale: JitPack needed for android-week-view

### Community 105 - "Architecture Dead Ends"
Cohesion: 0.43
Nodes (7): BaseApplication snapshot listeners, EventBus events, Realm local cache, Rationale: MVP+ButterKnife+Realm+EventBus dead end, BaseApplication god object, Phase 2 ViewBinding, Flow replaces EventBus/Realm, Rationale: no Realm Kotlin

### Community 106 - "Firebase Backend Overview"
Cohesion: 0.33
Nodes (7): BookStatus lifecycle, Firebase backend (no custom server), Firestore collections, PrefUtil, Realtime Database chat messages, Booking status colors, Strengths worth keeping

### Community 107 - "JDK 17 & TLS Rationale"
Cohesion: 0.33
Nodes (7): Rationale: no Java 21+ before AGP change, Cloudflare Zero Trust TLS gateway, JDK 17 requirement, Project-local toolchain (.android-sdk, .jdk, .certs), Custom TLS truststore, Rationale: JDK 17 not newer, Rationale: merged truststore for PKIX errors

### Community 109 - "MVP Framework Review"
Cohesion: 0.40
Nodes (6): Registration terms (static HTML, placeholder Dieu 1-5), Custom MVP framework (Contact/Presenter/Fragment), MainActivity drawer navigation, PresenterFactory, Phase 4 Navigation Compose, remove MVP base, PresenterFactory problems

### Community 110 - "Album Contract"
Cohesion: 0.33
Nodes (3): AlbumContact, PresenterViewOps, ViewOps

### Community 112 - "Home Contract"
Cohesion: 0.33
Nodes (3): HomeContact, PresenterViewOps, ViewOps

### Community 113 - "Chat Bubble Tails"
Cohesion: 0.33
Nodes (6): Chat bubble tail (white), Chat bubble tail, own message (light grey), Chat bubble tail, other party message (pink), Chat bubble tail, Sent message bubble tail, Received message bubble tail

### Community 114 - "Proposed Architecture"
Cohesion: 0.33
Nodes (6): UploadFileService, Hilt DI, Phase 1 Kotlin, Hilt, repositories, Proposed core/data/domain/feature architecture, Repository layer, WorkManager

### Community 115 - "Product Flavors"
Cohesion: 0.50
Nodes (5): Flavor dimension env, Product flavor envReal, Product flavor envTest, Config (envReal), Config (envTest)

### Community 119 - "Background Photos"
Cohesion: 0.83
Nodes (4): Home Background Photo, My Profile Background Photo, Atmospheric Landscape Photo (conical hat figure, moody sky), Photographer Photography Theme

### Community 120 - "Launcher Icon"
Cohesion: 1.00
Nodes (4): App launcher icon xhdpi (colorful aperture, blue stripes), App launcher icon xxhdpi, App launcher icon xxxhdpi, App launcher icon

### Community 121 - "Back Arrow Icon"
Cohesion: 0.67
Nodes (3): White Back Arrow Icon, Back Navigation, Top Bar

### Community 122 - "Rating Star Icons"
Cohesion: 1.00
Nodes (3): Gray Star Icon (unselected), Yellow Star Icon (selected), Rating Star

### Community 123 - "Security & Config Keys"
Cohesion: 0.67
Nodes (3): Security and ops issues, Required config keys, Committed API keys issue

## Ambiguous Edges - Review These
- `MyProjectFragment` → `ProjectFragment`  [AMBIGUOUS]
  app/src/main/java/com/paditech/mvpbase/screen/project/ProjectFragment.java · relation: semantically_similar_to
- `Custom MVP framework (Contact/Presenter/Fragment)` → `Registration terms (static HTML, placeholder Dieu 1-5)`  [AMBIGUOUS]
  app/src/main/assets/list_terms.html · relation: conceptually_related_to

## Knowledge Gaps
- **148 isolated node(s):** `Config`, `Config`, `ALERT`, `ERROR`, `WAITING` (+143 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 458 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **68 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `MyProjectFragment` and `ProjectFragment`?**
  _Edge tagged AMBIGUOUS (relation: semantically_similar_to) - confidence is low._
- **What is the exact relationship between `Custom MVP framework (Contact/Presenter/Fragment)` and `Registration terms (static HTML, placeholder Dieu 1-5)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `User` connect `User Model Setters` to `Date/Time Picker Dialogs`, `Image Collage & Multi-Select`, `Fragment View Contracts`, `Screen Fragments & Menu`, `Profile Comments Adapter`, `Booking Model & Contract`, `Chat Room Model`, `Update Profile Imports`, `Presenters & Firestore Albums`, `Chat Message Contract`, `Auth Providers & Device`, `Album Upload Service`, `Domain Models & Firestore`, `Booking Status Lifecycle`, `Booking Card Binding`, `Price Range Enum`, `Register/Profile Contracts`, `Book Fragment`, `Firebase Helper Imports`, `Find Photographer Screen`, `Photographer Adapter`, `Photographer Profile Fields`, `Application Imports`, `User Info Listener`, `Firestore Save Helpers`, `Attendee List Adapter`, `Time Picker Listener`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **Why does `app module build.gradle` connect `Gradle Dependencies` to `Gradle Plugins`, `Jetifier & JitPack`, `Device & File Managers`, `Test Scaffolding`, `Toolchain env.sh`, `Product Flavors`, `Manifest Permissions`, `Manifest Components`, `Android SDK Install`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Why does `MVPFragment` connect `MVP Fragment Base` to `Date/Time Picker Dialogs`, `Bottom Dialog Base`, `Image Collage & Multi-Select`, `Fragment View Contracts`, `Screen Fragments & Menu`, `Profile Comments Adapter`, `Chat Message Contract`, `Image Picker Manager`, `Calendar Fragment`, `Message List Screen`, `Base Fragment`, `Base Activity & Toast`, `My Project Pager`, `Device & File Managers`, `Create Album Screen`, `Find Project Screen`, `Location Manager APIs`, `Book Fragment`, `Get File Manager`, `Location Manager`, `Album Fragment`, `Home Fragment`, `Find Photographer Screen`, `List Booking Fragment`, `Confirm Dialog Listeners`, `Create Project Fragment`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **What connects `Config`, `Config`, `ALERT` to the rest of the system?**
  _148 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Legacy REST APIClient` be split into smaller, more focused modules?**
  _Cohesion score 0.057859703020993344 - nodes in this community are weakly interconnected._