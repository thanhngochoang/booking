// Where S14.02 lives in the router, shared by the offer listener and the
// push-open path so neither stacks a second offer screen.
import 'package:go_router/go_router.dart';

/// S14.02's path prefix (`/work/instant/offer/:offerId`).
const offerPathPrefix = '/work/instant/offer/';

bool isOfferPath(String path) => path.startsWith(offerPathPrefix);

/// An S14.02 is anywhere in the stack (on top or under other pages).
bool offerScreenInStack(GoRouter router) {
  bool walk(List<RouteMatchBase> matches) => matches.any(
    (m) => switch (m) {
      ImperativeRouteMatch(:final matches) => walk(matches.matches),
      ShellRouteMatch(:final matches) => walk(matches),
      _ => isOfferPath(m.matchedLocation),
    },
  );
  return walk(router.routerDelegate.currentConfiguration.matches);
}

/// The page on top is an S14.02.
bool offerScreenOnTop(GoRouter router) => isOfferPath(router.state.uri.path);
