import 'package:flutter_test/flutter_test.dart';
import 'package:kamuradar/screens/home_feed_screen.dart';
import 'package:kamuradar/data/announcements_catalog.dart';

void main() {
  test('KPSS Score Matching and Eligibility Logic Test', () {
    final catalog = AnnouncementsCatalog.staticCatalog;
    expect(catalog.isNotEmpty, isTrue);

    // Test a sample item
    final sample = catalog.first;
    expect(sample.minKpssScore, isNonNegative);

    // Test score comparison: a high score should be eligible
    final isEligibleHigh = sample.isEligibleForKpss(95.0);
    expect(isEligibleHigh, isTrue);

    // Count how many items match a standard KPSS score of 70.0
    final eligible70 = catalog.where((c) => c.status == "Açık" && c.isEligibleForKpss(70.0)).length;
    final eligible85 = catalog.where((c) => c.status == "Açık" && c.isEligibleForKpss(85.0)).length;

    // Higher score should qualify for at least as many or more positions
    expect(eligible85 >= eligible70, isTrue);
    expect(eligible70 > 0, isTrue);
  });
}
