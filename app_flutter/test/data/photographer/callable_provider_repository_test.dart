import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photobooking/data/photographer/callable_provider_repository.dart';
import 'package:photobooking/data/photographer/provider_repository.dart';
import 'package:photobooking/data/content/provider_type.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

void main() {
  late _MockFunctions functions;
  late _MockCallable callable;
  late FakeFirebaseFirestore db;
  late CallableProviderRepository repo;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    db = FakeFirebaseFirestore();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = CallableProviderRepository(functions: functions, db: db);
  });

  test('setType sends the choice and returns the server type', () async {
    final result = _MockResult();
    when(() => result.data).thenReturn({'providerType': 'artist'});
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);

    final type = await repo.setType(ProviderChoice.individual);

    expect(type, ProviderType.artist);
    final options =
        verify(
              () => functions.httpsCallable(
                'setProviderType',
                options: captureAny(named: 'options'),
              ),
            ).captured.single
            as HttpsCallableOptions;
    expect(options.timeout, const Duration(seconds: 15));
    verify(() => callable.call<Object?>({'type': 'individual'})).called(1);
  });

  test(
    "not_eligible from the server becomes ProviderError('not_eligible')",
    () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'x',
          code: 'failed-precondition',
          details: {'code': 'not_eligible'},
        ),
      );
      await expectLater(
        repo.setType(ProviderChoice.studio),
        throwsA(
          isA<ProviderError>().having((e) => e.code, 'code', 'not_eligible'),
        ),
      );
    },
  );

  test('setStudioAddress sends the address without null fields', () async {
    final result = _MockResult();
    when(() => result.data).thenReturn({});
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);

    await repo.setStudioAddress(
      const StudioAddressInput(line: '1 Lê Lợi', district: 'Q1', city: 'HCM'),
    );

    verify(
      () => callable.call<Object?>({
        'line': '1 Lê Lợi',
        'district': 'Q1',
        'city': 'HCM',
      }),
    ).called(1);
  });

  test('myStudioAddress reads the private doc, null when absent', () async {
    expect(await repo.myStudioAddress('u1'), isNull);
    await db.doc('photographers/u1/private/studioAddress').set({
      'line': '1 Lê Lợi',
      'ward': 'Bến Nghé',
      'district': 'Q1',
      'city': 'HCM',
      'lat': 10.77,
      'lng': 106.7,
      'updatedAt': Timestamp.now(),
    });
    final a = await repo.myStudioAddress('u1');
    expect(a?.line, '1 Lê Lợi');
    expect(a?.ward, 'Bến Nghé');
    expect((a?.lat, a?.lng), (10.77, 106.7));
  });
}
