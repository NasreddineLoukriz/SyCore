import 'dart:io';

import 'package:flutter/material.dart';

import 'screens/hosn_screen.dart';
import 'screens/jahr_screen.dart';
import 'screens/login_screen.dart';
import 'screens/operator_screen.dart';
import 'screens/samam_screen.dart';
import 'screens/vault_screen.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

void main() => runApp(const SycoreApp());

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
      // Set before signing in: the Shell is created the moment the account
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
    return MaterialApp(
      title: 'SYCORE',
      debugShowCheckedModeBanner: false,
      theme: SyTheme.build(),
      home: AnimatedBuilder(
        animation: state,
        builder: (_, __) =>
            state.signedIn
                ? Shell(state: state, startTab: _startTab)
                : LoginScreen(state: state),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.icon, this.label, this.blurb, this.build);
  final IconData icon;
  final String label;
  final String blurb;
  final Widget Function(AppState) build;
}

final _tabs = <_Tab>[
  _Tab(Icons.lock_outline, 'Vault',
      'One vault key, many devices, no re-encryption', (s) => VaultScreen(state: s)),
  _Tab(Icons.mail_outline, 'Messages',
      'HOSN · two readers: you and one person', (s) => HosnScreen(state: s)),
  _Tab(Icons.groups_outlined, 'Group',
      'SAMAM · an epoch key per membership change', (s) => SamamScreen(state: s)),
  _Tab(Icons.public, 'Public',
      'JAHR · public content, signed authorship', (s) => JahrScreen(state: s)),
  _Tab(Icons.dns_outlined, 'Operator',
      'What the server can actually see', (s) => OperatorScreen(state: s)),
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

  @override
  void didUpdateWidget(covariant Shell old) {
    super.didUpdateWidget(old);
    if (old.startTab != widget.startTab) index = widget.startTab;
  }

  AppState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    final persona = personas.where((p) => p.id == s.userId).firstOrNull;
    final color = Color(persona?.color ?? 0xFF4DD4C6);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 236,
            decoration: const BoxDecoration(
              color: SyTheme.surface,
              border: Border(right: BorderSide(color: SyTheme.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: SyTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Text('SYCORE',
                          style: SyTheme.h1
                              .copyWith(fontSize: 16, letterSpacing: 3)),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SyTheme.surfaceAlt,
                    border: Border.all(color: SyTheme.line),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: color.withValues(alpha: 0.18),
                        child: Text(
                          (persona?.name ?? '?')[0],
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(persona?.name ?? s.userId,
                                style: SyTheme.h2.copyWith(fontSize: 13)),
                            Text(s.userId, style: SyTheme.mono(10.5)),
                          ],
                        ),
                      ),
                      Pill(s.account!.deviceId, color: color),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < _tabs.length; i++)
                  _NavItem(
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: i == index,
                    onTap: () => setState(() => index = i),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle,
                              size: 8,
                              color: s.online ? SyTheme.ok : SyTheme.danger),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              s.online ? 'server reachable' : 'server offline',
                              style: SyTheme.mono(10.5,
                                  s.online ? SyTheme.muted : SyTheme.danger),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('build 0.1.0 · wire v1', style: SyTheme.mono(10)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: s.signOut,
                        icon: const Icon(Icons.lock, size: 14),
                        label: const Text('Lock vault'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: SyTheme.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_tabs[index].label, style: SyTheme.h1),
                            Text(_tabs[index].blurb,
                                style: SyTheme.mono(11.5, SyTheme.muted)),
                          ],
                        ),
                      ),
                      Pill('project ${AppState.project}', color: SyTheme.violet),
                      const SizedBox(width: 8),
                      Pill('fingerprint ${s.account!.fingerprint}',
                          color: SyTheme.muted),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: s.refreshHealth,
                        icon: const Icon(Icons.sync, size: 17),
                        tooltip: 'Refresh server state',
                      ),
                    ],
                  ),
                ),
                if (s.busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  key: ValueKey(index),
                  child: _tabs[index].build(s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? SyTheme.accent.withValues(alpha: 0.10) : null,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: selected
                    ? SyTheme.accent.withValues(alpha: 0.35)
                    : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 17, color: selected ? SyTheme.accent : SyTheme.muted),
              const SizedBox(width: 11),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? SyTheme.text : SyTheme.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
