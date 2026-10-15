// test/support/my_albums_world.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/features/album/add_posts_sheet.dart';
import 'package:photobooking/features/album/edit_album_sheet.dart';
import 'package:photobooking/features/album/my_albums_screen.dart';

import 'create_post_world.dart';
import 'screen_host.dart';

/// The signed-in photographer of [CreatePostWorld] with S24.02 mounted at
/// `/me/albums`, plus stub routes for what it opens.
class MyAlbumsWorld extends CreatePostWorld {
  late GoRouter router;

  Widget app({
    String location = '/me/albums',
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    Widget stub(BuildContext _, GoRouterState s) => Text('stub ${s.uri}');
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/me/albums', builder: (_, _) => const MyAlbumsScreen()),
        GoRoute(path: '/u/:uid/albums/:albumId', builder: stub),
        GoRoute(path: '/action', builder: stub),
        GoRoute(path: '/profile', builder: stub),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: overrides,
      brightness: brightness,
      textScale: textScale,
    );
  }
}

/// Uses a phone-sized, tall view so sheets lay out fully.
void usePhone(WidgetTester tester, {double width = 390, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens S24.03 / S24.04 from a button and records what they return.
class SheetHost extends StatelessWidget {
  const SheetHost.edit({super.key, this.album, this.addPosts = true})
    : addTo = null;
  const SheetHost.addPosts({super.key, required AlbumSummary this.addTo})
    : album = null,
      addPosts = true;

  final AlbumSummary? album;
  final bool addPosts;
  final AlbumSummary? addTo;

  static final results = <Object?>[];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const Key('open'),
        onPressed: () async {
          final target = addTo;
          results.add(
            target != null
                ? await showAddPostsSheet(context, album: target)
                : await showEditAlbumSheet(
                    context,
                    album: album,
                    addPostsAfterCreate: addPosts,
                  ),
          );
        },
        child: const Text('mở'),
      ),
    ),
  );
}
