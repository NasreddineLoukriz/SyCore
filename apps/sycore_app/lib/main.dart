import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n.dart';
import 'screens/hosn_screen.dart';
import 'screens/jahr_screen.dart';
import 'screens/login_screen.dart';
import 'screens/operator_screen.dart';
import 'screens/samam_screen.dart';
import 'screens/vault_screen.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Where the chosen language is remembered between runs. A preference, not a
/// secret, so it lives in the config directory; `SYCORE_HOME` and the vault are
/// left alone.
File _langFile() {
  final base = Platform.environment['XDG_CONFIG_HOME'] ??
      '${Platform.environment['HOME'] ?? '/tmp'}/.config';
  return File('$base/sycore/lang');
}

/// Persist the current language. A read-only home is not a reason to stop.
void _remember() {
  try {
    final f = _langFile();
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(appLang.value.name);
  } catch (_) {}
}

void main() {
  // Order of precedence: SYCORE_LANG (a rehearsal pins the language), then the
  // last choice made with the switch in the header, then English.
  final forced = Platform.environment['SYCORE_LANG'];
  if (forced == 'ar' || forced == 'en') {
    appLang.value = forced == 'ar' ? AppLang.ar : AppLang.en;
  } else {
    try {
      if (_langFile().readAsStringSync().trim() == 'ar') {
        appLang.value = AppLang.ar;
      }
    } catch (_) {
      // No preference yet, or no home directory: English, quietly.
    }
  }
  _remember();
  appLang.addListener(_remember);
  runApp(const SycoreApp());
}

class SycoreApp extends StatefulWidget {
  const SycoreApp({super.key});

  @override
  State<SycoreApp> createState() => _SycoreAppState();
}

class _SycoreAppState extends State<SycoreApp> {
  late final AppState state = AppState();
  int _startTab = 0;

  @override
  void initState() {
    super.initState();
    state.ping();
    _autoDemo();
  }

  /// `SYCORE_DEMO_USER=usr_ali SYCORE_DEMO_TAB=2 ./sycore_app`
  /// opens straight into an account. Used for demo runs and screenshots.
  Future<void> _autoDemo() async {
    final user = Platform.environment['SYCORE_DEMO_USER'];
    if (user == null || user.isEmpty) return;
    final tab = int.tryParse(Platform.environment['SYCORE_DEMO_TAB'] ?? '');
    if (tab != null) {
      // Set before signing in: the shell is created the moment the account
      // becomes available, so it must already know which tab to open.
      _startTab = tab.clamp(0, _tabs.length - 1);
    }
    await state.signIn(user, AppState.demoPassword);
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        final t = Strings(lang);
        return MaterialApp(
          title: t.t('app_name'),
          debugShowCheckedModeBanner: false,
          theme: SyTheme.build(ar: t.isAr),
          locale: Locale(t.isAr ? 'ar' : 'en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AnimatedBuilder(
            animation: state,
            builder: (_, __) => state.signedIn
                ? Shell(state: state, startTab: _startTab)
                : LoginScreen(state: state),
          ),
        );
      },
    );
  }
}

class _Tab {
  const _Tab(this.labelKey, this.blurbKey, this.build);
  final String labelKey;
  final String blurbKey;
  final Widget Function(AppState) build;
}

final _tabs = <_Tab>[
  _Tab('nav_vault', 'nav_blurb_vault', (s) => VaultScreen(state: s)),
  _Tab('nav_messages', 'nav_blurb_messages', (s) => HosnScreen(state: s)),
  _Tab('nav_group', 'nav_blurb_group', (s) => SamamScreen(state: s)),
  _Tab('nav_public', 'nav_blurb_public', (s) => JahrScreen(state: s)),
  _Tab('nav_operator', 'nav_blurb_operator', (s) => OperatorScreen(state: s)),
];

class Shell extends StatefulWidget {
  const Shell({super.key, required this.state, this.startTab = 0});

  final AppState state;
  final int startTab;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int index = widget.startTab;

  AppState get s => widget.state;

  @override
  void didUpdateWidget(covariant Shell old) {
    super.didUpdateWidget(old);
    if (old.startTab != widget.startTab) index = widget.startTab;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tx = Theme.of(context).textTheme;
    final persona = personas.where((p) => p.id == s.userId).firstOrNull;
    final color = Color(persona?.color ?? 0xFF35564A);

    return Scaffold(
      body: Column(
        children: [
          // ── masthead ───────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SyTheme.line)),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(28, 0, 20, 0),
            height: 66,
            child: Row(
              children: [
                Text(
                  t.t('app_name'),
                  style: SyTheme.display(t.isAr ? 20 : 21,
                      weight: FontWeight.w700),
                ),
                const SizedBox(width: 22),
                Container(width: 1, height: 20, color: SyTheme.line),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < _tabs.length; i++)
                          _NavItem(
                            label: t.t(_tabs[i].labelKey),
                            selected: i == index,
                            onTap: () => setState(() => index = i),
                          ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => appLang.value =
                      t.isAr ? AppLang.en : AppLang.ar,
                  icon: const Icon(Icons.translate, size: 15),
                  label: Text(t.otherLanguageName),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 20, color: SyTheme.line),
                const SizedBox(width: 14),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Dot(color: color),
                        const SizedBox(width: 6),
                        Text(
                          persona?.nameIn(t) ?? s.userId,
                          style: tx.titleSmall?.copyWith(color: SyTheme.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${s.userId} · ${s.account!.deviceId}',
                      style: tx.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: t.t('lock_vault'),
                  child: IconButton(
                    onPressed: s.signOut,
                    icon: const Icon(Icons.lock_outline, size: 17),
                  ),
                ),
              ],
            ),
          ),
          if (s.busy) const LinearProgressIndicator(minHeight: 1.5),
          // ── page ──────────────────────────────────────────────
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                key: ValueKey(index),
                child: _tabs[index].build(s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 22, 12, 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? SyTheme.ink : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: tx.titleSmall?.copyWith(
            color: selected ? SyTheme.ink : SyTheme.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
