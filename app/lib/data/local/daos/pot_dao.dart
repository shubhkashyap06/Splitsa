import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/pots_table.dart';

part 'pot_dao.g.dart';

@DriftAccessor(tables: [PotsTable, PotContributionsTable])
class PotDao extends DatabaseAccessor<AppDatabase> with _$PotDaoMixin {
  PotDao(super.db);

  Stream<List<PotsTableData>> watchPots() =>
      (select(potsTable)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Stream<List<PotContributionsTableData>> watchContributions() => (select(
    potContributionsTable,
  )..where((t) => t.deletedAt.isNull())).watch();
}
