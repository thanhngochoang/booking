import 'dart:async';

import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class FakeDeliveryRepository implements DeliveryRepository {
  final Map<String, List<DeliveryRound>> rounds = {};
  final Map<String, DeliveryLink?> links = {};
  final Map<String, List<StagedSample>> stagedSamples = {};

  final _roundsController = StreamController<String>.broadcast();
  final _linksController = StreamController<String>.broadcast();
  final _stagedController = StreamController<String>.broadcast();

  final List<
      ({
        String bookingId,
        String uploaderId,
        String fileId,
        PickedImage image,
      })> uploadCalls = [];
  final List<
      ({
        String bookingId,
        List<String> sampleIds,
        String link,
        int photoCount,
        String? note,
      })> submitCalls = [];
  final List<String> approveCalls = [];
  final List<
      ({
        String bookingId,
        String? note,
        List<DeliveryPhotoNote> photoNotes,
        bool extra,
      })> revisionCalls = [];
  final List<({String bookingId, bool grant})> extraRoundCalls = [];

  int nextRound = 1;
  DeliveryErrorCode? nextError;

  void seedRound(String bookingId, DeliveryRound round) {
    rounds.putIfAbsent(bookingId, () => []).add(round);
    _roundsController.add(bookingId);
  }

  void seedLink(String bookingId, DeliveryLink? link) {
    links[bookingId] = link;
    _linksController.add(bookingId);
  }

  void seedStagedSample(String bookingId, StagedSample sample) {
    stagedSamples.putIfAbsent(bookingId, () => []).add(sample);
    _stagedController.add(bookingId);
  }

  @override
  Stream<List<DeliveryRound>> watchRounds(String bookingId) async* {
    yield rounds[bookingId] ?? const [];
    yield* _roundsController.stream
        .where((id) => id == bookingId)
        .map((id) => rounds[id] ?? const []);
  }

  @override
  Stream<DeliveryLink?> watchLink(String bookingId) async* {
    yield links[bookingId];
    yield* _linksController.stream
        .where((id) => id == bookingId)
        .map((id) => links[id]);
  }

  @override
  Stream<List<StagedSample>> watchStagedSamples(String bookingId) async* {
    yield stagedSamples[bookingId] ?? const [];
    yield* _stagedController.stream
        .where((id) => id == bookingId)
        .map((id) => stagedSamples[id] ?? const []);
  }

  @override
  Stream<UploadEvent> uploadSample({
    required String bookingId,
    required String uploaderId,
    required String fileId,
    required PickedImage image,
  }) async* {
    uploadCalls.add((
      bookingId: bookingId,
      uploaderId: uploaderId,
      fileId: fileId,
      image: image,
    ));
    yield const UploadEvent.progress(0.5);
    yield UploadEvent.done(
      UploadedMedia(
        url: 'https://storage/$fileId.jpg',
        storagePath: 'deliveryUploads/$bookingId/$uploaderId/$fileId.jpg',
      ),
    );
  }

  @override
  Future<void> discardSample({
    required String bookingId,
    required String uploaderId,
    required String fileId,
  }) async {
    stagedSamples[bookingId]?.removeWhere((s) => s.fileId == fileId);
    _stagedController.add(bookingId);
  }

  @override
  Future<int> submit({
    required String bookingId,
    required List<String> sampleIds,
    required String link,
    required int photoCount,
    String? note,
  }) async {
    if (nextError != null) {
      throw DeliveryException(nextError!.name);
    }
    submitCalls.add((
      bookingId: bookingId,
      sampleIds: sampleIds,
      link: link,
      photoCount: photoCount,
      note: note,
    ));
    final r = nextRound++;
    return r;
  }

  @override
  Future<void> approve(String bookingId) async {
    if (nextError != null) {
      throw DeliveryException(nextError!.name);
    }
    approveCalls.add(bookingId);
  }

  @override
  Future<void> requestRevision({
    required String bookingId,
    String? note,
    List<DeliveryPhotoNote> photoNotes = const [],
    bool extra = false,
  }) async {
    if (nextError != null) {
      throw DeliveryException(nextError!.name);
    }
    revisionCalls.add((
      bookingId: bookingId,
      note: note,
      photoNotes: photoNotes,
      extra: extra,
    ));
  }

  @override
  Future<void> answerExtraRound({
    required String bookingId,
    required bool grant,
  }) async {
    if (nextError != null) {
      throw DeliveryException(nextError!.name);
    }
    extraRoundCalls.add((bookingId: bookingId, grant: grant));
  }

  @override
  Future<String> imageUrl(String storagePath) async {
    return 'https://example.com/$storagePath';
  }
}
