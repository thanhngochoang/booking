// lib/features/organizer/widgets/ticket_type_sheet.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';

/// What the S30.04 type sheet answers.
sealed class TicketTypeEdit {
  const TicketTypeEdit();
}

class TicketTypeSaved extends TicketTypeEdit {
  const TicketTypeSaved(this.type);
  final EntryTicketType type;
}

class TicketTypeDeleted extends TicketTypeEdit {
  const TicketTypeDeleted();
}

/// Opens the name and price sheet of one ticket type ([existing] null adds
/// one). A [sold] type can only be hidden, never deleted (S30.04 rule).
Future<TicketTypeEdit?> showTicketTypeSheet(
  BuildContext context, {
  EntryTicketType? existing,
  bool sold = false,
}) => showAppSheet<TicketTypeEdit>(
  context,
  builder: (_) => TicketTypeSheet(existing: existing, sold: sold),
);

class TicketTypeSheet extends StatefulWidget {
  const TicketTypeSheet({super.key, this.existing, this.sold = false});

  final EntryTicketType? existing;
  final bool sold;

  @override
  State<TicketTypeSheet> createState() => _TicketTypeSheetState();
}

class _TicketTypeSheetState extends State<TicketTypeSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _price = TextEditingController(
    text: widget.existing == null ? '' : groupVnd(widget.existing!.price),
  );
  late bool _hidden = widget.existing?.hidden ?? false;
  bool _nameError = false;
  bool _priceError = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final price = ticketTypePriceOf(_price.text);
    setState(() {
      _nameError = !ticketTypeNameOk(_name.text);
      _priceError = price == null;
    });
    if (_nameError || _priceError) return;
    Navigator.of(context).pop(
      TicketTypeSaved(
        EntryTicketType(
          id: widget.existing?.id ?? '',
          name: _name.text.trim(),
          price: price!,
          hidden: _hidden,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final editing = widget.existing != null;
    // ListTiles paint on a Material: the sheet frame is a coloured box.
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.s5,
          AppSpace.s2,
          AppSpace.s5,
          AppSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            OrgSheetHeader(
              editing ? l.s3004_typeSheetEdit : l.s3004_typeSheetAdd,
            ),
            const SizedBox(height: AppSpace.s3),
            TextField(
              key: const Key('type-name'),
              controller: _name,
              maxLength: ticketTypeNameMax,
              decoration: InputDecoration(
                labelText: l.s3004_typeName,
                errorText: _nameError ? l.s3004_typeNameLength : null,
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('type-price'),
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: const [VndInputFormatter()],
              decoration: InputDecoration(
                labelText: l.s3004_typePrice,
                errorText: _priceError ? l.s3004_typePriceInvalid : null,
              ),
            ),
            if (editing && widget.sold)
              SwitchListTile(
                key: const Key('type-hide'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.s3004_hideType),
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v),
              ),
            const SizedBox(height: AppSpace.s4),
            AppButton.outline(
              l.s3004_typeSave,
              key: const Key('type-save'),
              onPressed: _save,
            ),
            if (editing && !widget.sold)
              OrgDangerText(
                l.s3004_deleteType,
                key: const Key('type-delete'),
                onPressed: () =>
                    Navigator.of(context).pop(const TicketTypeDeleted()),
              ),
          ],
        ),
      ),
    );
  }
}
