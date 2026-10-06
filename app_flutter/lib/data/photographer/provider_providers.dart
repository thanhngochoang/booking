import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/photographer/callable_provider_repository.dart';
import 'package:photobooking/data/photographer/provider_repository.dart';

final providerRepositoryProvider = Provider<ProviderRepository>(
  (ref) => CallableProviderRepository(),
);
