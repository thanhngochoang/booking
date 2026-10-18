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
    final list = stagedSamples.putIfAbsent(bookingId, () => []);
    final idx = list.indexWhere((s) => s.fileId == sample.fileId);
    if (idx != -1) {
      list[idx] = sample;
    } else {
      list.add(sample);
    }
    _stagedController.add(bookingId);
  }

  @override
  Stream<List<DeliveryRound>> watchRounds(String bookingId) {
    late final StreamController<List<DeliveryRound>> c;
    StreamSubscription? sub;
    c = StreamController<List<DeliveryRound>>(
      onListen: () {
        c.add(List.unmodifiable(rounds[bookingId] ?? const []));
        sub = _roundsController.stream.where((id) => id == bookingId).listen((_) {
          c.add(List.unmodifiable(rounds[bookingId] ?? const []));
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<DeliveryLink?> watchLink(String bookingId) {
    late final StreamController<DeliveryLink?> c;
    StreamSubscription? sub;
    c = StreamController<DeliveryLink?>(
      onListen: () {
        c.add(links[bookingId]);
        sub = _linksController.stream.where((id) => id == bookingId).listen((_) {
          c.add(links[bookingId]);
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<List<StagedSample>> watchStagedSamples(String bookingId) {
    late final StreamController<List<StagedSample>> c;
    StreamSubscription? sub;
    c = StreamController<List<StagedSample>>(
      onListen: () {
        c.add(List.unmodifiable(stagedSamples[bookingId] ?? const []));
        sub = _stagedController.stream.where((id) => id == bookingId).listen((_) {
          c.add(List.unmodifiable(stagedSamples[bookingId] ?? const []));
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<UploadEvent> uploadSample({
    required String bookingId,
    required String uploaderId,
    required String fileId,
    required PickedImage image,
  }) {
    uploadCalls.add((
      bookingId: bookingId,
      uploaderId: uploaderId,
      fileId: fileId,
      image: image,
    ));
    Stream<UploadEvent> run() async* {
      yield const UploadEvent.progress(0.5);
      yield UploadEvent.done(
        UploadedMedia(
          url: 'https://storage/$fileId.jpg',
          storagePath: 'deliveryUploads/$bookingId/$uploaderId/$fileId.jpg',
        ),
      );
    }
    return run();
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
      final code = switch (nextError!) {
        DeliveryErrorCode.notReady => 'not_ready',
        DeliveryErrorCode.notEligible => 'not_eligible',
        DeliveryErrorCode.conflict => 'conflict',
        DeliveryErrorCode.permissionDenied => 'permission_denied',
        DeliveryErrorCode.notFound => 'not_found',
        DeliveryErrorCode.invalidArgument => 'invalid_argument',
        DeliveryErrorCode.network => 'network',
        DeliveryErrorCode.unknown => 'unknown',
      };
      throw DeliveryException(code);
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
