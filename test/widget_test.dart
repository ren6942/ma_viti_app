import 'package:flutter_test/flutter_test.dart';
import 'package:ma_viti_app/database_helper.dart';

void main() {
  test('Test de calculerCampagne de DatabaseHelper', () {
    final db = DatabaseHelper.instance;

    // Mois < 11 -> Même année
    expect(db.calculerCampagne('2025-05-15'), '2025');

    // Mois >= 11 -> Année suivante
    expect(db.calculerCampagne('2025-11-01'), '2026');
    expect(db.calculerCampagne('2025-12-31'), '2026');
  });
}
