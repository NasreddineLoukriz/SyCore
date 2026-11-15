import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sycore_app/l10n.dart';
import 'package:sycore_app/screens/login_screen.dart';
import 'package:sycore_app/state.dart';
import 'package:sycore_app/theme.dart';

void main() {
  setUp(() => appLang.value = AppLang.en);

  test('both languages define exactly the same keys', () {
    expect(arTable.keys.toSet(), enTable.keys.toSet());
    for (final e in enTable.entries) {
      expect(e.value, isNotEmpty, reason: e.key);
      expect(arTable[e.key], isNotEmpty, reason: e.key);
    }
  });

  test('placeholders match across languages', () {
    Set<String> vars(String s) =>
        RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();
    for (final e in enTable.entries) {
      expect(vars(arTable[e.key]!), vars(e.value),
          reason: 'placeholder mismatch on ${e.key}');
    }
  });

  test('the two languages are actually different', () {
    final en = Strings(AppLang.en);
    final ar = Strings(AppLang.ar);
    expect(ar.t('app_name'), isNot(en.t('app_name')));
    expect(ar.t('sign_in'), isNot(en.t('sign_in')));
    expect(ar.t('nav_vault'), isNot(en.t('nav_vault')));
  });

  test('variables are substituted, not left as braces', () {
    expect(Strings(AppLang.en).t('unlock', {'name': 'Ali'}), contains('Ali'));
    expect(Strings(AppLang.ar).t('chars', {'n': 42}), contains('42'));
    expect(Strings(AppLang.en).t('chars', {'n': 42}),
        isNot(contains('{')));
  });

  testWidgets('the login screen speaks the selected language',
      (tester) async {
    final state = AppState();
    await tester.pumpWidget(
      ValueListenableBuilder<AppLang>(
        valueListenable: appLang,
        builder: (context, lang, _) {
          final t = Strings(lang);
          return MaterialApp(
            theme: SyTheme.build(ar: t.isAr),
            locale: Locale(t.isAr ? 'ar' : 'en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: LoginScreen(state: state),
          );
        },
      ),
    );

    // English: the claim, the action, and the switch to Arabic.
    expect(find.text('SYCORE'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('الدخول'), findsNothing);

    // Flip the switch the way the header does.
    appLang.value = AppLang.ar;
    await tester.pump();

    expect(find.text('الدخول'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('English'), findsOneWidget);
    // Arabic lays the page out right to left.
    expect(
      Directionality.of(tester.element(find.text('الدخول'))),
      TextDirection.rtl,
    );
  });
}
