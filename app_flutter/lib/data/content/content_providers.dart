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
