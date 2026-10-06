import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:photobooking/data/content/post_summary.dart';

import '../content/firestore_post_repository_test.dart' show postDoc;

Future<void> seedPost(FakeFirebaseFirestore db, PostSummary p) =>
    db.collection('posts').doc(p.id).set(postDoc(p));
