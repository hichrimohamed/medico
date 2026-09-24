import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/features/auth/data/auth_service.dart';
import 'package:medico/ui/ui.dart';

import 'render_harness.dart';

void main() {
  // The Google mark is drawn, not shipped as a bitmap. Magnified here so a
  // human can confirm it reads as the real mark and not an approximation.
  testWidgets('sso buttons magnified', (tester) async {
    await render(
      tester,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GoogleGlyph(size: 150),
                const SizedBox(height: 40),
                SsoButton(provider: SsoProvider.google, onPressed: () {}),
                const SizedBox(height: 12),
                SsoButton(provider: SsoProvider.apple, onPressed: () {}),
                const SizedBox(height: 12),
                SsoButton(
                  provider: SsoProvider.google,
                  busy: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      device: Device.phone,
      name: 'sso_buttons',
      settle: false,
    );
  });
}
