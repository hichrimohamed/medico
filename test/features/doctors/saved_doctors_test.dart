import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico/core/api/api_exception.dart';
import 'package:medico/features/doctors/presentation/saved_doctors_screen.dart';
import 'package:medico/features/doctors/presentation/widgets/doctor_card.dart';
import 'package:medico/theme/app_theme.dart';

import '../../support/fakes.dart';

Widget _app(FakePatientRepository patient, {VoidCallback? onFindDoctor}) {
  return withFakeServices(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: SavedDoctorsScreen(
            patient: patient,
            onFindDoctor: onFindDoctor,
          ),
        ),
      ),
    ),
  );
}

void main() {
  // The heart is icon-only, so its name lives in the semantics tree and these
  // tests read it there — the same string a screen reader announces.
  late SemanticsHandle semantics;

  setUp(() {
    semantics = TestWidgetsFlutterBinding.ensureInitialized().ensureSemantics();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(420, 1600);
  });

  tearDown(() {
    semantics.dispose();
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('it lists the doctors the server has kept', (tester) async {
    await tester.pumpWidget(
      _app(FakePatientRepository(favourites: {'d2', 'd5'})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dr. Thomas Moore'), findsOneWidget);
    expect(find.text('Dr. Hugo Lindqvist'), findsOneWidget);
    expect(find.text('Dr. William James'), findsNothing);
    // Whole doctors, not just ids: the card needs the price and the rating,
    // and `/me/favourites` populates them.
    expect(find.textContaining('84'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
  });

  testWidgets('every heart here is filled, because that is the list',
      (tester) async {
    await tester.pumpWidget(_app(FakePatientRepository(favourites: {'d2'})));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Remove from saved doctors'), findsOneWidget);
    expect(find.bySemanticsLabel('Save this doctor'), findsNothing);
  });

  testWidgets('unsaving removes the row and tells the server', (tester) async {
    final patient = FakePatientRepository(favourites: {'d2', 'd5'});
    await tester.pumpWidget(_app(patient));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Remove from saved doctors').first);
    await tester.pumpAndSettle();

    expect(patient.favouriteIds, {'d5'});
    expect(find.text('Dr. Thomas Moore'), findsNothing);
    expect(find.text('Dr. Hugo Lindqvist'), findsOneWidget);
  });

  testWidgets('unsaving offers an undo, and the undo puts them back',
      (tester) async {
    final patient = FakePatientRepository(favourites: {'d2', 'd5'});
    await tester.pumpWidget(_app(patient));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Remove from saved doctors').first);
    await tester.pumpAndSettle();

    expect(find.text('Removed Dr. Thomas Moore from saved.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(patient.favouriteIds, {'d2', 'd5'});
    expect(find.text('Dr. Thomas Moore'), findsOneWidget);
  });

  testWidgets('a removal the server refuses puts the row back',
      (tester) async {
    final patient = FakePatientRepository(favourites: {'d2', 'd5'});
    await tester.pumpWidget(_app(patient));
    await tester.pumpAndSettle();

    // Loaded fine; now the network goes.
    patient.writeFailure = ApiException.offline;

    await tester.tap(find.bySemanticsLabel('Remove from saved doctors').first);
    await tester.pumpAndSettle();

    expect(find.text('Dr. Thomas Moore'), findsOneWidget,
        reason: 'the server kept them, so the list has to as well');
    expect(patient.favouriteIds, contains('d2'));
    expect(
      find.text("We couldn't reach Medico. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('a list that will not load says so, and offers a retry',
      (tester) async {
    await tester.pumpWidget(
      _app(FakePatientRepository(failure: ApiException.offline)),
    );
    await tester.pumpAndSettle();

    expect(find.text('We could not load your saved doctors'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the heart is a control of its own, not the tail of the card',
      (tester) async {
    // It was not, once: the card's InkWell swallowed the heart's node, so the
    // whole row announced as "…, 4.8, Remove from saved doctors" with a single
    // tap action that opened the doctor. A screen-reader user could not unsave
    // anybody. `container: true` on the heart's Semantics is what separates
    // them, and this is the test that says so.
    await tester.pumpWidget(_app(FakePatientRepository(favourites: {'d2'})));
    await tester.pumpAndSettle();

    final card = tester.getSemantics(find.byType(DoctorListCard));
    expect(card.label, isNot(contains('Remove from saved')),
        reason: 'the card describes the doctor, not the heart');
    expect(card.label, contains('Dr. Thomas Moore'));
    expect(
      'Dr. Thomas Moore'.allMatches(card.label).length,
      1,
      reason: 'the avatar and the text must not both name the doctor',
    );

    final heart = tester.getSemantics(find.byType(FavouriteButton));
    expect(heart.label, 'Remove from saved doctors');
    expect(heart.flagsCollection.isButton, isTrue,
        reason: 'it announces as a button, not as part of a row');
    // Tristate: a heart that is off reports isFalse, not "absent".
    expect(heart.flagsCollection.isToggled.name, 'isTrue',
        reason: 'and as already saved, so the action is "remove"');
  });

  testWidgets('nothing saved says what the heart is for', (tester) async {
    var asked = false;
    await tester.pumpWidget(
      _app(FakePatientRepository(favourites: {}),
          onFindDoctor: () => asked = true),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved doctors yet'), findsOneWidget);
    await tester.tap(find.text('Find a doctor'));
    await tester.pumpAndSettle();
    expect(asked, isTrue);
  });
}
