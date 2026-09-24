import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/features/doctors/data/doctor.dart';
import 'package:medico/features/doctors/presentation/doctor_detail_screen.dart';

import '../support/fixtures.dart';

import 'render_harness.dart';

final Doctor _doctor =
    kSampleDoctors.firstWhere((doctor) => doctor.id == 'd2');

void main() {
  testWidgets('doctor detail — about', (tester) async {
    await render(
      tester,
      child: DoctorDetailScreen(doctor: _doctor),
      device: Device.phone,
      name: 'doctor_about',
    );
  });

  testWidgets('doctor detail — availability', (tester) async {
    await render(
      tester,
      child: DoctorDetailScreen(doctor: _doctor),
      device: Device.phone,
      name: 'doctor_availability',
      after: (tester) async {
        await tester.tap(find.text('Availability'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('11:00'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('doctor detail — experience', (tester) async {
    await render(
      tester,
      child: DoctorDetailScreen(doctor: _doctor),
      device: Device.phone,
      name: 'doctor_experience',
      after: (tester) async {
        // "Experience" is also a stat tile label; the tab is the later one.
        await tester.tap(find.text('Experience').last);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('doctor detail — reviews', (tester) async {
    await render(
      tester,
      child: DoctorDetailScreen(doctor: _doctor),
      device: Device.phone,
      name: 'doctor_reviews',
      after: (tester) async {
        await tester.dragUntilVisible(
          find.text('Reviews'),
          find.byType(ListView).first,
          const Offset(-120, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reviews'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('doctor detail — 200% text scale', (tester) async {
    await render(
      tester,
      child: DoctorDetailScreen(doctor: _doctor),
      device: Device.phone,
      name: 'doctor_text200',
      textScale: 2,
    );
  });
}
