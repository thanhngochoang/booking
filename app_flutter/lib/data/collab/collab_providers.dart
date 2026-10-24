import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/collab/firestore_collab_repository.dart';

final collabRepositoryProvider = Provider<CollabRepository>(
  (ref) => FirestoreCollabRepository(),
);
