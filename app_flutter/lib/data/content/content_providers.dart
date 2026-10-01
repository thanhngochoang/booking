import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';

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
