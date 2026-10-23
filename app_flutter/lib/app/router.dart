import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/account/account_providers.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/features/account/delete_account_screen.dart';
import 'package:photobooking/features/account/privacy_screen.dart';
import 'package:photobooking/features/account/restore_account_screen.dart';
import 'package:photobooking/features/addons/addons_screen.dart';
import 'package:photobooking/features/album/album_detail_screen.dart';
import 'package:photobooking/features/album/my_albums_screen.dart';
import 'package:photobooking/features/awards/my_awards_screen.dart';
import 'package:photobooking/features/badges/badges_screen.dart';
import 'package:photobooking/features/auth/login_screen.dart';
import 'package:photobooking/features/auth/register_screen.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/features/booking/booking_detail_screen.dart';
import 'package:photobooking/features/booking/booking_flow_state.dart';
import 'package:photobooking/features/booking/booking_sheet_page.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/features/payment/payment_screen.dart';
import 'package:photobooking/features/calendar/my_calendar_screen.dart';
import 'package:photobooking/features/chat/chat_list_screen.dart';
import 'package:photobooking/features/chat/chat_screen.dart';
import 'package:photobooking/features/chat/inquiry_entry.dart';
import 'package:photobooking/features/contact/add_phone_screen.dart';
import 'package:photobooking/features/earnings/earnings_screen.dart';
import 'package:photobooking/features/earnings/payout_account_screen.dart';
import 'package:photobooking/features/event_create/create_event_screen.dart';
import 'package:photobooking/features/event_manage/manage_event_screen.dart';
import 'package:photobooking/features/event_chat/event_chat_screen.dart';
import 'package:photobooking/features/event_manage/my_events_screen.dart';
import 'package:photobooking/features/events/event_screen.dart';
import 'package:photobooking/features/events/event_share_composer.dart';
import 'package:photobooking/features/events/events_list_screen.dart';
import 'package:photobooking/features/jobs/job_post_screen.dart';
import 'package:photobooking/features/jobs/job_screen.dart';
import 'package:photobooking/features/explore/explore_screen.dart';
import 'package:photobooking/features/explore/search/explore_search_screen.dart';
import 'package:photobooking/features/help/help_screen.dart';
import 'package:photobooking/features/help/support_chat_screen.dart';
import 'package:photobooking/features/home/home_screen.dart';
import 'package:photobooking/features/instant_work/instant_job_screen.dart';
import 'package:photobooking/features/instant_work/live_shutter_screen.dart';
import 'package:photobooking/features/instant_work/offer_screen.dart';
import 'package:photobooking/features/notifications/notification_settings_screen.dart';
import 'package:photobooking/features/notifications/notifications_screen.dart';
import 'package:photobooking/features/onboarding/role_screen.dart';
import 'package:photobooking/features/onboarding/session_error_screen.dart';
import 'package:photobooking/features/onboarding/splash_screen.dart';
import 'package:photobooking/features/photo/photo_detail_screen.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_screen.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_intro_screen.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_screen.dart';
import 'package:photobooking/features/saved/followers_screen.dart';
import 'package:photobooking/features/saved/following_screen.dart';
import 'package:photobooking/features/saved/saved_screen.dart';
import 'package:photobooking/features/profile/profile_tab.dart';
import 'package:photobooking/features/safety/blocked_users_screen.dart';
import 'package:photobooking/features/settings/edit_profile_screen.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';
import 'package:photobooking/features/shell/tab_shell.dart';
import 'package:photobooking/features/skills/skills_screen.dart';
import 'package:photobooking/features/studio/my_studio_screen.dart';
import 'package:photobooking/features/studio/studio_members_screen.dart';
import 'package:photobooking/features/spots/my_spot_schedules_screen.dart';
import 'package:photobooking/features/spots/spot_screen.dart';
import 'package:photobooking/features/spots/spot_schedule_edit_screen.dart';
import 'package:photobooking/features/spots/spots_screen.dart';
import 'package:photobooking/features/verification/verify_business_screen.dart';
import 'package:photobooking/features/verification/verify_fee_screen.dart';
import 'package:photobooking/features/verification/verify_identity_screen.dart';
import 'package:photobooking/features/verification/verify_phone_screen.dart';
import 'package:photobooking/features/verification/verify_rules_screen.dart';
import 'package:photobooking/features/verification/verify_start_screen.dart';

const _authRoutes = {'/login', '/register'};
const _onboardingRoute = '/onboarding/role';
const _splashRoute = '/splash';
const _sessionErrorRoute = '/session-error';
const _restoreAccountRoute = '/account/restore';
const _nonResumable = {
  ..._authRoutes,
  _onboardingRoute,
  _splashRoute,
  _sessionErrorRoute,
  _restoreAccountRoute,
};

String _toSplash(String location) =>
    '$_splashRoute?from=${Uri.encodeComponent(location)}';

/// Pure redirect rule; see router_test.dart.
///
/// While the session is still being restored (auth or profile loading) the app
/// parks on /splash and remembers where it was going in `from`, so a signed-in
/// user never sees the login form and deep links survive a cold start.
String? computeRedirect({
  bool authLoading = false,
  required bool signedIn,
  required bool profileLoaded,
  bool profileError = false,
  required bool needsRole,
  bool isAccountLocked = false,
  required String location,
  String? from,
}) {
  final onAuth = _authRoutes.contains(location);
  if (authLoading) return location == _splashRoute ? null : _toSplash(location);
  if (!signedIn) {
    if (location == _splashRoute) return '/login';
    return onAuth ? null : '/login';
  }
  if (profileError) {
    return location == _sessionErrorRoute ? null : _sessionErrorRoute;
  }
  if (!profileLoaded) {
    return location == _splashRoute ? null : _toSplash(location);
  }
  if (isAccountLocked) {
    return location == _restoreAccountRoute ? null : _restoreAccountRoute;
  }
  if (location == _restoreAccountRoute) {
    return AppTab.home.path;
  }
  if (needsRole) return location == _onboardingRoute ? null : _onboardingRoute;
  if (location == _splashRoute) {
    return (from == null || _nonResumable.contains(from))
        ? AppTab.home.path
        : from;
  }
  if (_nonResumable.contains(location)) return AppTab.home.path;
  return null;
}

/// S06.04 and S08.01 are for photographers only (spec screens/README.md "Vai trò").
String? photographerOnlyRedirect(UserRole? role) =>
    role == UserRole.photographer ? null : AppTab.home.path;

/// Rebuilds GoRouter's redirect when auth or profile changes.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
    ref.listen(accountLockProvider, (_, _) => notifyListeners());
  }
  final Ref ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = ref.read(authStateProvider);
    final profile = ref.read(currentProfileProvider);
    final lock = ref.read(accountLockProvider);
    final signedIn = auth.value != null;
    final profileError = signedIn && profile.hasError;
    return computeRedirect(
      authLoading: !auth.hasValue,
      signedIn: signedIn,
      profileLoaded:
          !signedIn ||
          (!profile.hasError && profile.hasValue && profile.value != null),
      profileError: profileError,
      needsRole: profile.value?.needsRole ?? false,
      isAccountLocked: lock.value != null,
      location: state.matchedLocation,
      from: state.uri.queryParameters['from'],
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  String? photographersOnly() =>
      photographerOnlyRedirect(ref.read(currentProfileProvider).value?.role);
  return GoRouter(
    initialLocation: AppTab.home.path,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: _splashRoute, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: _sessionErrorRoute,
        builder: (_, _) => const SessionErrorScreen(),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: _onboardingRoute, builder: (_, _) => const RoleScreen()),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (_, _) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (_, _) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: 'blocked',
            builder: (_, _) => const BlockedUsersScreen(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (_, _) => const PrivacyScreen(),
          ),
          GoRoute(
            path: 'delete-account',
            builder: (_, _) => const DeleteAccountScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/account/restore',
        builder: (_, _) => const RestoreAccountScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/phone',
        builder: (_, state) =>
            AddPhoneScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
      GoRoute(
        path: '/verify/phone',
        builder: (_, state) =>
            VerifyPhoneScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
      GoRoute(
        path: verifyStartPath,
        builder: (_, _) => const VerifyStartScreen(),
        routes: [
          GoRoute(path: 'rules', builder: (_, _) => const VerifyRulesScreen()),
          GoRoute(
            path: 'fee',
            builder: (_, _) => const VerifyFeeScreen(),
            routes: [
              GoRoute(
                path: 'pay',
                builder: (_, state) => PaymentScreen(
                  subject: const VerificationFeePay(),
                  initial: state.extra as PaymentInstructions?,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/verify/identity',
        builder: (_, state) => VerifyIdentityScreen(
          method: state.uri.queryParameters['method'] == IdentityMethod.nfc.code
              ? IdentityMethod.nfc
              : IdentityMethod.vneid,
        ),
      ),
      GoRoute(
        path: '/verify/business',
        builder: (_, _) => const VerifyBusinessScreen(),
      ),
      GoRoute(
        path: '/setup',
        redirect: (_, _) {
          final away = photographersOnly();
          if (away != null) {
            return away;
          }
          final uid = ref.read(authRepositoryProvider).currentUser?.uid;
          return setupResumePath(
            uid == null ? 1 : ref.read(setupDraftStoreProvider).step(uid),
          );
        },
      ),
      GoRoute(
        path: '/setup/1',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const SetupIntroScreen(),
      ),
      GoRoute(
        path: '/setup/2',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const SetupPackagesScreen(),
      ),
      GoRoute(
        path: '/work/calendar',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const MyCalendarScreen(),
      ),
      GoRoute(
        path: '/work/instant',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const LiveShutterScreen(),
      ),
      GoRoute(
        path: '/work/instant/offer/:offerId',
        redirect: (_, _) => photographersOnly(),
        builder: (_, state) =>
            OfferScreen(offerId: state.pathParameters['offerId']!),
      ),
      GoRoute(
        path: '/work/instant/:id',
        redirect: (_, _) => photographersOnly(),
        builder: (_, state) =>
            InstantJobScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/work/earnings',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const EarningsScreen(),
        routes: [
          GoRoute(
            path: 'account',
            redirect: (_, _) => photographersOnly(),
            builder: (_, _) => const PayoutAccountScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/setup/3',
        builder: (_, _) => const SkillsScreen(mode: SkillsMode.setup),
      ),
      GoRoute(
        path: '/profile/skills',
        builder: (_, _) => const SkillsScreen(mode: SkillsMode.edit),
      ),
      GoRoute(
        path: '/profile/skills/evidence',
        builder: (_, state) => SkillsScreen(
          mode: SkillsMode.edit,
          openEvidenceFor: state.uri.queryParameters['skill'],
        ),
      ),
      GoRoute(
        path: '/setup/4',
        builder: (_, state) => ContactSetupScreen(
          popOnDone: state.uri.queryParameters['from'] == 'settings',
        ),
      ),
      GoRoute(
        path: '/explore/search',
        builder: (_, _) => const ExploreSearchScreen(),
      ),
      GoRoute(
        path: '/p/:postId',
        builder: (_, state) =>
            PhotoDetailScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '/spots',
        builder: (_, state) => SpotsScreen(
          area: state.uri.queryParameters['area'],
        ),
      ),
      GoRoute(
        path: '/spots/:spotId',
        builder: (_, state) => SpotScreen(
          spotId: state.pathParameters['spotId']!,
          date: state.uri.queryParameters['date'],
        ),
      ),
      GoRoute(
        path: '/u/:uid/book',
        pageBuilder: (_, state) => BookingSheetPage(
          args: BookingFlowArgs(
            photographerId: state.pathParameters['uid']!,
            serviceId: state.uri.queryParameters['serviceId'],
            day:
                state.uri.queryParameters['day'] ??
                state.uri.queryParameters['date'],
            area: state.uri.queryParameters['area'],
            scheduleId: state.uri.queryParameters['scheduleId'],
            slotOfferId: state.uri.queryParameters['offerId'],
            start: state.uri.queryParameters['start'],
          ),
        ),
      ),
      GoRoute(
        path: '/b/:id/pay',
        builder: (_, state) => PaymentScreen(
          subject: BookingPay(state.pathParameters['id']!),
          initial: state.extra as PaymentInstructions?,
        ),
      ),
      GoRoute(
        path: '/e/:eventId/pay/:regId',
        builder: (_, state) => PaymentScreen(
          subject: TicketPay(
            state.pathParameters['eventId']!,
            state.pathParameters['regId']!,
          ),
          initial: state.extra as PaymentInstructions?,
        ),
      ),
      ...bookingDetailRoutes(),
      GoRoute(path: '/chats', builder: (_, _) => const ChatListScreen()),
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, state) => ChatScreen(
          chatId: state.pathParameters['chatId']!,
          serviceId: state.uri.queryParameters['serviceId'],
          initialReschedule: state.uri.queryParameters['reschedule'] == '1',
        ),
      ),
      GoRoute(
        path: '/u/:uid/ask',
        builder: (_, state) => InquiryEntry(
          photographerId: state.pathParameters['uid']!,
          serviceId: state.uri.queryParameters['serviceId'],
        ),
      ),
      GoRoute(path: '/events', builder: (_, _) => const EventsListScreen()),
      GoRoute(path: '/events/mine', builder: (_, _) => const MyEventsScreen()),
      GoRoute(
        path: '/events/new',
        builder: (_, state) =>
            CreateEventScreen(draftId: state.uri.queryParameters['draft']),
      ),
      GoRoute(
        path: '/events/:eventId/manage',
        builder: (_, state) =>
            ManageEventScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/e/:eventId',
        builder: (_, state) =>
            EventScreen(eventId: state.pathParameters['eventId']!),
        routes: [
          // Back from "add phone": the register sheet opens over S11.02.
          GoRoute(
            path: 'join',
            builder: (_, state) => EventScreen(
              eventId: state.pathParameters['eventId']!,
              openRegister: true,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/e/:eventId/timeline',
        builder: (_, state) => EventScreen(
          eventId: state.pathParameters['eventId']!,
          initialTab: EventTab.timeline,
          initialReview: state.uri.queryParameters['review'] == '1',
        ),
      ),
      // S11.05 share form and S11.06 group chat.
      GoRoute(
        path: '/e/:eventId/share',
        builder: (_, state) =>
            EventShareComposer(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/e/:eventId/chat',
        builder: (_, state) =>
            EventChatScreen(eventId: state.pathParameters['eventId']!),
      ),
      // S15 and S16 Job Posts and Quotes (#139).
      // `new` before `:id`.
      GoRoute(
        path: '/jobs/new',
        builder: (_, state) => JobPostScreen(
          fromJobId: state.uri.queryParameters['from'],
          editJobId: state.uri.queryParameters['edit'],
        ),
      ),
      GoRoute(
        path: '/jobs/:id',
        builder: (_, state) => JobScreen(
          jobId: state.pathParameters['id']!,
        ),
        routes: [
          GoRoute(
            path: 'quote',
            builder: (_, state) => JobScreen(
              jobId: state.pathParameters['id']!,
              openQuote: true,
            ),
          ),
          GoRoute(
            path: 'applications',
            builder: (_, state) => JobScreen(
              jobId: state.pathParameters['id']!,
            ),
            routes: [
              GoRoute(
                path: ':quoteId',
                builder: (_, state) => JobScreen(
                  jobId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'pay',
                    builder: (_, state) => JobScreen(
                      jobId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/me/albums', builder: (_, _) => const MyAlbumsScreen()),
      GoRoute(path: '/me/awards', builder: (_, _) => const MyAwardsScreen()),
      // S26.03 (individual, NAG) and S26.01 (studio owner); the server refuses
      // the wrong side's calls, the settings rows pick the right screen.
      GoRoute(
        path: '/me/studio',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const MyStudioScreen(),
      ),
      GoRoute(
        path: '/studio/members',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const StudioMembersScreen(),
      ),
      GoRoute(
        path: '/me/addons',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const AddonsScreen(),
      ),
      // S29.03 and S29.04 (#194); `new` before `:scheduleId`.
      GoRoute(
        path: '/me/spot-schedules',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const MySpotSchedulesScreen(),
      ),
      GoRoute(
        path: '/me/spot-schedules/new',
        redirect: (_, _) => photographersOnly(),
        builder: (_, state) => SpotScheduleEditScreen(
          spotId: state.uri.queryParameters['spotId'],
        ),
      ),
      GoRoute(
        path: '/me/spot-schedules/:scheduleId',
        redirect: (_, _) => photographersOnly(),
        builder: (_, state) => SpotScheduleEditScreen(
          scheduleId: state.pathParameters['scheduleId'],
        ),
      ),
      GoRoute(
        path: '/me/saved',
        builder: (_, state) => SavedScreen(
          initialTab: state.uri.queryParameters['tab'] == 'photographers'
              ? SavedTab.photographers
              : SavedTab.posts,
        ),
      ),
      GoRoute(
        path: '/me/following',
        builder: (_, _) => const FollowingScreen(),
      ),
      GoRoute(
        path: '/me/followers',
        redirect: (_, _) {
          final role = ref.read(currentProfileProvider).value?.role;
          if (role != UserRole.photographer) {
            return '/profile';
          }
          return null;
        },
        builder: (_, _) => const FollowersScreen(),
      ),
      GoRoute(
        path: '/u/:uid/albums/:albumId',
        builder: (_, state) => AlbumDetailScreen(
          uid: state.pathParameters['uid']!,
          albumId: state.pathParameters['albumId']!,
        ),
      ),
      GoRoute(
        path: '/u/:uid/badges',
        builder: (_, state) => BadgesScreen(uid: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: '/u/:uid',
        builder: (_, state) => PhotographerProfileScreen(
          uid: state.pathParameters['uid']!,
          initialSection: profileSectionFromQuery(
            state.uri.queryParameters['tab'],
          ),
        ),
      ),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      GoRoute(path: '/help/chat', builder: (_, _) => const SupportChatScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => TabShell(shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.home.path,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.explore.path,
                builder: (_, _) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.action.path,
                builder: (_, state) => ActionTab(
                  specialty: state.uri.queryParameters['specialty'],
                  style: state.uri.queryParameters['style'],
                  area: state.uri.queryParameters['area'],
                  caption: state.uri.queryParameters['caption'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.bookings.path,
                builder: (_, state) => BookingsTab(
                  tab: state.uri.queryParameters['tab'],
                  highlight: state.uri.queryParameters['highlight'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.profile.path,
                builder: (_, _) => const ProfileTab(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
