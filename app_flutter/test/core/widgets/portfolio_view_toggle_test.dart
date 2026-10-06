import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('toggle marks the selected view for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        PortfolioViewToggle(value: PortfolioView.albums, onChanged: (_) {}),
      ),
    );
    final albums = tester.getSemantics(find.bySemanticsLabel('Album'));
    final timeline = tester.getSemantics(
      find.bySemanticsLabel('Dòng thời gian'),
    );
    expect(albums.flagsCollection.isSelected, Tristate.isTrue);
    expect(timeline.flagsCollection.isSelected, Tristate.isFalse);
    expect(albums.role, SemanticsRole.tab);
    expect(timeline.role, SemanticsRole.tab);
    handle.dispose();
  });

  testWidgets('tapping the other segment reports it', (tester) async {
    PortfolioView? seen;
    await tester.pumpWidget(
      hostWidget(
        PortfolioViewToggle(
          value: PortfolioView.albums,
          onChanged: (v) => seen = v,
        ),
      ),
    );
    await tester.tap(find.text('Dòng thời gian'));
    expect(seen, PortfolioView.timeline);
    expect(
      tester.getSize(find.byType(InkWell).first).height,
      greaterThanOrEqualTo(48),
    );
  });
}
