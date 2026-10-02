import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/contact/contact_launcher.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/contact/functions_contact_link_repository.dart';

final contactLinkRepositoryProvider = Provider<ContactLinkRepository>(
  (ref) => FunctionsContactLinkRepository(),
);

final externalLauncherProvider = Provider<ExternalLauncher>(
  (ref) => const UrlLauncherExternalLauncher(),
);

final contactLauncherProvider = Provider<ContactLauncher>(
  (ref) => ContactLauncher(
    links: ref.watch(contactLinkRepositoryProvider),
    launcher: ref.watch(externalLauncherProvider),
  ),
);
