import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/home/home_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';

import '../../support/content_fixtures.dart';
import '../../support/create_post_world.dart';
import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

GoRouter _router() => GoRouter(
  initialLocation: AppTab.action.path,
  routes: [
    GoRoute(path: AppTab.action.path, builder: (_, _) => const ActionTab()),
    GoRoute(path: AppTab.home.path, builder: (_, _) => const Text('home stub')),
    GoRoute(path: '/setup/2', builder: (_, _) => const Text('setup packages')),
  ],
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('publish on the middle tab, land on Home with the post first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = DiscoveryWorld(role: UserRole.photographer);
    await w.init();
    w.photographers.add(fixturePhotographer(w.uid, name: 'Tôi'));
    w.services.add(fixtureService('s1x', photographerId: w.uid));
    final publisher = FakePostPublisher(
      posts: w.posts,
      clock: () => fixtureNow,
    );
    final router = GoRouter(
      initialLocation: AppTab.action.path,
      routes: [
        GoRoute(path: AppTab.action.path, builder: (_, _) => const ActionTab()),
        GoRoute(path: AppTab.home.path, builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/setup/2', builder: (_, _) => const Text('setup')),
      ],
    );
    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...w.overrides,
          imagePickerProvider.overrideWithValue(
            FakeImagePicker([
              [const PickedImage(path: '/tmp/none.jpg', name: 'n.jpg')],
            ]),
          ),
          mediaUploaderProvider.overrideWithValue(FakeMediaUploader()),
          postPublisherProvider.overrideWithValue(publisher),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _tap(tester, find.byKey(const Key('create-add')));
    await _tap(tester, find.byKey(const Key('create-service')));
    await _tap(tester, find.textContaining('Chân dung 2 giờ'));
    await _tap(tester, find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();

    final id = publisher.published.single.id;
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(Key('post-$id')), findsOneWidget);
    expect(find.byKey(const Key('post-a')), findsNothing);
  });

  testWidgets('"Thêm gói" opens the package setup', (tester) async {
    final w = CreatePostWorld();
    await w.init();
    await tester.pumpWidget(
      screenRouterApp(router: _router(), overrides: w.overrides),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('create-add-service')));
    expect(find.text('setup packages'), findsOneWidget);
  });

  testWidgets('a photographer\'s middle tab is Create post', (tester) async {
    final w = CreatePostWorld();
    await w.init();
    await tester.pumpWidget(
      screenRouterApp(router: _router(), overrides: w.overrides),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CreatePostScreen), findsOneWidget);
  });

  testWidgets('a customer\'s middle tab is not Create post', (tester) async {
    final w = CreatePostWorld(role: UserRole.customer);
    await w.init();
    await tester.pumpWidget(
      screenRouterApp(router: _router(), overrides: w.overrides),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CreatePostScreen), findsNothing);
  });
}
