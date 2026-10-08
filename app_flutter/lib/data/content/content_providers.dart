import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/content/firestore_post_publisher.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';
import 'package:photobooking/data/content/post_publisher.dart';

final postRepositoryProvider = Provider<PostRepository>(
  (ref) => FirestorePostRepository(),
);

final postEngagementRepositoryProvider = Provider<PostEngagementRepository>(
  (ref) => FirestoreEngagementRepository(),
);

final photographerRepositoryProvider = Provider<PhotographerRepository>(
  (ref) => FirestorePhotographerRepository(),
);

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => FirestoreServiceRepository(),
);

final postPublisherProvider = Provider<PostPublisher>(
  (ref) => FirestorePostPublisher(),
);

/// Bumped each time the signed-in user creates a post: the S10.01 publish
/// (`PostComposerController.publish`), the S11.05 event share
/// (`ShareController.share`) and the S05 review shared with photos
/// (`ReviewController.submit(share: true)`). Lists of the user's own posts
/// watch it to re-read (S09.01 grid and counts), because the shell keeps the
/// Hồ sơ tab mounted and nothing else would make them read again.
class OwnPostsChanged extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final ownPostsChangedProvider = NotifierProvider<OwnPostsChanged, int>(
  OwnPostsChanged.new,
);
