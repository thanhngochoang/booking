// test/support/fake_ticket_scanner.dart
import 'package:flutter/widgets.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/event_manage/checkin_sheet.dart';
import 'package:photobooking/features/event_manage/ticket_scanner.dart';

/// A ticket scanner that answers from a queue instead of opening a camera.
/// An empty queue is "the person closed the scanner".
///
/// With [manual] it opens a sheet with the app's "Nhập mã vé" field
/// ([ManualTicketCodeEntry]) instead, so a test types the code the way a host
/// does when the camera is off.
class FakeTicketScanner implements TicketScanner {
  FakeTicketScanner([List<String?> codes = const []]) : _codes = List.of(codes);

  final List<String?> _codes;
  int calls = 0;
  bool manual = false;

  void enqueue(String? code) => _codes.add(code);

  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    if (manual) {
      return showAppSheet<String>(
        context,
        builder: (sheet) => Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: ManualTicketCodeEntry(
            onSubmit: (code) => Navigator.of(sheet).pop(code),
          ),
        ),
      );
    }
    return _codes.isEmpty ? null : _codes.removeAt(0);
  }
}
