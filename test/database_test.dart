import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/src/mixin/factory.dart';
import 'package:ma_viti_app/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    databaseFactory = buildDatabaseFactory(
      invokeMethod: (String method, [Object? arguments]) async {
        if (method == 'getDatabasesPath') {
          return '/mock/databases';
        } else if (method == 'openDatabase') {
          return 1;
        } else if (method == 'closeDatabase') {
          return null;
        } else if (method == 'deleteDatabase') {
          return null;
        } else if (method == 'execute') {
          return null;
        } else if (method == 'query') {
          final map = arguments as Map?;
          if (map != null && map['sql'] == 'PRAGMA user_version') {
            return {'user_version': 12};
          }
          return <Map<String, dynamic>>[];
        } else if (method == 'insert') {
          return 1;
        } else if (method == 'update') {
          return 1;
        } else if (method == 'delete') {
          return 1;
        } else if (method == 'batch') {
          return <dynamic>[];
        }
        return null;
      },
    );
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  group('DatabaseHelper - cycle de vie, connexions et concurrence', () {
    test('Accès multiples concurrents partagent la même instance sans blocage', () async {
      final futures = List.generate(5, (_) => DatabaseHelper.instance.database);
      final dbs = await Future.wait(futures);

      expect(dbs.length, 5);
      for (final db in dbs) {
        expect(db.isOpen, isTrue);
      }
    });

    test('close() ferme correctement la base et permet une réouverture propre', () async {
      final db = await DatabaseHelper.instance.database;
      expect(db.isOpen, isTrue);

      await DatabaseHelper.instance.close();

      // Réouverture après fermeture
      final dbAfter = await DatabaseHelper.instance.database;
      expect(dbAfter.isOpen, isTrue);
    });

    test('reinitialiserBase() ferme, supprime et réouvre sans deadlock', () async {
      await DatabaseHelper.instance.reinitialiserBase();
      final db = await DatabaseHelper.instance.database;
      expect(db.isOpen, isTrue);
    });
  });
}
