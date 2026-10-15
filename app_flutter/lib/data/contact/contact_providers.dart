import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/backend_config.dart';
import 'package:photobooking/data/contact/contact_launcher.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/contact/functions_contact_link_repository.dart';
import 'package:photobooking/data/contact/http_contact_link_repository.dart';
import 'package:photobooking/data/http/api_providers.dart';

final contactLinkRepositoryProvider = Provider<ContactLinkRepository>((ref) {
  if (ref.watch(backendConfigProvider).uses(SelfhostedRepo.contactLink)) {
    return HttpContactLinkRepository(api: ref.watch(apiClientProvider));
  }
  return FunctionsContactLinkRepository();
});

final externalLauncherProvider = Provider<ExternalLauncher>(
  (ref) => const UrlLauncherExternalLauncher(),
);

final contactLauncherProvider = Provider<ContactLauncher>(
  (ref) => ContactLauncher(
    links: ref.watch(contactLinkRepositoryProvider),
    launcher: ref.watch(externalLauncherProvider),
  ),
);
