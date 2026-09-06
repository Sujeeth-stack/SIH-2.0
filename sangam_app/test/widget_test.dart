import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangam/core/status.dart';
import 'package:sangam/core/theme.dart';
import 'package:sangam/widgets/report_card.dart';
import 'package:sangam/widgets/status_chip.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: buildAppTheme(), home: Scaffold(body: child));

void main() {
  group('status vocabulary', () {
    test('raw codes become plain language', () {
      expect(ProblemStatus.label('IN_EXECUTION'), 'In progress');
      expect(ProblemStatus.label('CLOSED_WITH_IMPACT'), 'Resolved');
      expect(ProblemStatus.label('SUBMITTED'), 'Submitted');
    });

    test('an unknown status falls back to its code rather than blanking', () {
      expect(ProblemStatus.label('SOMETHING_NEW'), 'SOMETHING_NEW');
    });

    test('open and resolved are mutually exclusive', () {
      expect(ProblemStatus.isResolved('DEPLOYED'), isTrue);
      expect(ProblemStatus.isOpen('DEPLOYED'), isFalse);
      expect(ProblemStatus.isOpen('SUBMITTED'), isTrue);
      // Rejected is neither open work nor a resolved problem.
      expect(ProblemStatus.isOpen('REJECTED'), isFalse);
      expect(ProblemStatus.isResolved('REJECTED'), isFalse);
    });
  });

  testWidgets('report card shows title, subtitle and a plain-language status',
      (tester) async {
    await tester.pumpWidget(_host(ReportCard(
      title: 'Handpump dry for three weeks',
      subtitle: 'Dumka · 2 days ago',
      status: 'IN_EXECUTION',
      trailingNote: 'JH-DMK-000417',
      onTap: () {},
    )));

    expect(find.text('Handpump dry for three weeks'), findsOneWidget);
    expect(find.text('Dumka · 2 days ago'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('JH-DMK-000417'), findsOneWidget);
  });

  testWidgets('report card is tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(ReportCard(
      title: 'Broken culvert',
      subtitle: 'Ranchi',
      status: 'SUBMITTED',
      onTap: () => taps++,
    )));

    await tester.tap(find.byType(ReportCard));
    expect(taps, 1);
  });

  testWidgets('status chip colour tracks the status', (tester) async {
    await tester.pumpWidget(_host(const Column(
      children: [StatusChip('CLOSED_WITH_IMPACT'), StatusChip('REJECTED')],
    )));

    final resolved = tester.widget<Text>(find.text('Resolved'));
    final rejected = tester.widget<Text>(find.text('Not accepted'));
    expect(resolved.style?.color, AppColors.success);
    expect(rejected.style?.color, AppColors.danger);
  });
}
