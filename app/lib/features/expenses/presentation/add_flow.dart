import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pots/presentation/widgets/contribute_sheet.dart';
import 'widgets/add_expense_sheet.dart';
import 'widgets/expense_type_sheet.dart';

/// Single entry point for every "add" path: the raised tab-bar button,
/// a room's empty state, and the `/quick-add?type=` fast-launch shortcuts
/// (PROJECT_BRIEF.md §5–6). [quickAddType] is already allow-listed by the
/// router before it gets here.
Future<void> startAddFlow(
  BuildContext context,
  WidgetRef ref, {
  String? roomId,
  String? quickAddType,
}) async {
  if (quickAddType == 'pot-contribution') {
    await ContributeSheet.show(context);
    return;
  }
  if (quickAddType == 'personal') {
    await AddExpenseSheet.show(
      context,
      const ExpenseContext(type: ExpenseType.personal),
    );
    return;
  }
  if (roomId != null) {
    await AddExpenseSheet.show(
      context,
      ExpenseContext(type: ExpenseType.split, roomId: roomId),
    );
    return;
  }

  final picked = await ExpenseTypeSheet.show(
    context,
    initialType: quickAddType == 'split' ? ExpenseType.split : null,
  );
  if (picked != null && context.mounted) {
    await AddExpenseSheet.show(context, picked);
  }
}
