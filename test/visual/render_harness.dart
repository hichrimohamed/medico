import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/theme/app_theme.dart';

import '../support/fakes.dart';

const String _sdkFonts =
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';

/// Widget tests normally draw text as blank boxes. Loading the real families
/// turns these renders into something a human can actually review.
///
/// Inter Tight is loaded from the app's own assets rather than the SDK: these
/// renders are the only place a heading's real shape is checked, so loading a
/// stand-in would defeat the point.
Future<void> loadRealFonts() async {
  Future<void> family(String name, List<String> paths) async {
    final loader = FontLoader(name);
    for (final path in paths) {
      final bytes = await File(path).readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await family('Roboto', [
    '$_sdkFonts/Roboto-Regular.ttf',
    '$_sdkFonts/Roboto-Medium.ttf',
    '$_sdkFonts/Roboto-Bold.ttf',
  ]);
  await family('MaterialIcons', ['$_sdkFonts/MaterialIcons-Regular.otf']);
  await family('InterTight', [
    'assets/fonts/InterTight-SemiBold.ttf',
    'assets/fonts/InterTight-Bold.ttf',
  ]);
}

class Device {
  const Device(this.name, this.size, this.pixelRatio);

  final String name;
  final Size size;
  final double pixelRatio;

  static const phone = Device('phone_390x844', Size(390, 844), 2);
  static const phoneSmall = Device('phone_small_360x640', Size(360, 640), 2);
  static const tablet = Device('tablet_1024x768', Size(1024, 768), 2);
  static const phoneLandscape = Device('phone_landscape_844x390', Size(844, 390), 2);
}

/// Pumps [child] inside the real app theme at [device]'s size, decodes any
/// images for real, and writes a PNG under `test/visual/out/`.
Future<void> render(
  WidgetTester tester, {
  required Widget child,
  required Device device,
  required String name,
  double textScale = 1,
  bool reduceMotion = false,

  /// Renders against the dark theme. Dark mode is not an inversion of light —
  /// it picks different fills entirely — so it is reviewed as its own set of
  /// images, not assumed to follow.
  Brightness brightness = Brightness.light,
  /// Screens showing an indeterminate progress indicator never settle —
  /// advance a fixed number of frames instead.
  bool settle = true,

  /// Drive the screen into a particular state before the frame is captured.
  Future<void> Function(WidgetTester tester)? after,
}) async {
  await tester.runAsync(loadRealFonts);

  tester.view.devicePixelRatio = device.pixelRatio;
  tester.view.physicalSize = device.size * device.pixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    withFakeServices(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: child,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: widget!,
      ),
    )),
  );

  await tester.runAsync(() async {
    final element = tester.element(find.byType(MaterialApp));
    for (final asset in const [
      'assets/images/auth_hero.jpg',
      // The doctor portraits, or a card renders its initials fallback and the
      // golden records a face that never appears on a device.
      'assets/images/doctors/james.png',
      'assets/images/doctors/moore.png',
      'assets/images/doctors/farouk.png',
      'assets/images/doctors/raman.png',
      'assets/images/doctors/lindqvist.png',
      'assets/images/doctors/abebe.png',
    ]) {
      await precacheImage(AssetImage(asset), element);
    }
    // Give the decoded frames a chance to reach the image cache.
    await Future<void>.delayed(const Duration(milliseconds: 60));
  });

  if (settle) {
    await tester.pumpAndSettle();
    if (after != null) {
      await after(tester);
      await tester.pumpAndSettle();
    }
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}
