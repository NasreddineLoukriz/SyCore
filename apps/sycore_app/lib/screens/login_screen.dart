import 'package:flutter/material.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Persona _who = personas.first;
  final _password = TextEditingController(text: AppState.demoPassword);
  bool _create = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final ok = await widget.state.signIn(
      _who.id,
      _password.text,
      create: _create,
    );
    if (ok && mounted) setState(() => _create = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final t = context.s;
    final tx = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(48, 64, 48, 56),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── the claim ─────────────────────────────────
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.t('app_name').toUpperCase(),
                            style: tx.titleSmall?.copyWith(
                              letterSpacing: t.isAr ? 0 : 3,
                              color: SyTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(t.t('login_claim'), style: tx.displayLarge),
                          const SizedBox(height: 20),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: Text(
                              t.t('login_intro'),
                              style: tx.bodyLarge?.copyWith(
                                color: SyTheme.inkSoft,
                              ),
                            ),
                          ),
                          const SizedBox(height: 44),
                          _Flow(t: t),
                        ],
                      ),
                    ),
                    const SizedBox(width: 56),
                    // ── the lock ──────────────────────────────────
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(t.t('sign_in'), style: tx.headlineLarge),
                          const SizedBox(height: 8),
                          Text(t.t('login_help'), style: tx.bodySmall),
                          const SizedBox(height: 26),
                          for (final p in personas)
                            _PersonaRow(
                              persona: p,
                              t: t,
                              selected: p.id == _who.id,
                              onTap: () => setState(() => _who = p),
                            ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            onSubmitted: (_) => _go(),
                            style: tx.bodyMedium,
                            decoration: InputDecoration(
                              labelText: t.t('passphrase'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(t.t('kdf_note'), style: tx.labelSmall),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: s.busy ? null : _go,
                            child: Text(
                              s.busy
                                  ? t.t('unlocking')
                                  : (_create
                                      ? t.t('create_identity')
                                      : t.t('unlock',
                                          {'name': _who.nameIn(t)})),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: s.busy
                                  ? null
                                  : () => setState(() => _create = !_create),
                              child: Text(
                                _create ? t.t('create_on') : t.t('create_off'),
                                style: tx.bodySmall?.copyWith(
                                    color: SyTheme.accent),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (s.error(t) != null) ...[
                            Note(s.error(t)!, kind: NoteKind.danger),
                            const SizedBox(height: 16),
                          ],
                          const Divider(color: SyTheme.lineSoft, height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: StatusLine(
                                  on: s.online,
                                  text: s.online
                                      ? t.t('server_reachable',
                                          {'url': s.server})
                                      : t.t('server_unreachable',
                                          {'url': s.server}),
                                ),
                              ),
                              IconButton(
                                onPressed: s.ping,
                                icon: const Icon(Icons.refresh, size: 16),
                                tooltip: t.t('refresh'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // the one control that must always be reachable
          PositionedDirectional(
            top: 18,
            end: 24,
            child: TextButton.icon(
              onPressed: () =>
                  appLang.value = t.isAr ? AppLang.en : AppLang.ar,
              icon: const Icon(Icons.translate, size: 15),
              label: Text(t.otherLanguageName),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wire, in four lines. No boxes, no arrows — just numbered steps.
class _Flow extends StatelessWidget {
  const _Flow({required this.t});

  final Strings t;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    final rows = [
      ('01', 'login_flow_plain', 'login_flow_plain_note', SyTheme.ink),
      ('02', 'login_flow_sealed', 'login_flow_sealed_note', SyTheme.accent),
      ('03', 'login_flow_wire', 'login_flow_wire_note', SyTheme.muted),
      ('04', 'login_flow_server', 'login_flow_server_note', SyTheme.warn),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(r.$1,
                        style: SyTheme.mono(11, SyTheme.faint)),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.t(r.$2),
                          style: tx.titleSmall?.copyWith(color: r.$4)),
                      Text(t.t(r.$3), style: tx.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PersonaRow extends StatelessWidget {
  const _PersonaRow({
    required this.persona,
    required this.t,
    required this.selected,
    required this.onTap,
  });

  final Persona persona;
  final Strings t;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    final c = Color(persona.color);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: selected ? c : Colors.transparent,
              width: 2,
            ),
            bottom: const BorderSide(color: SyTheme.lineSoft),
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 10, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona.nameIn(t),
                    style: tx.titleMedium?.copyWith(
                      color: selected ? SyTheme.ink : SyTheme.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(t.t(persona.roleKey), style: tx.bodySmall),
                ],
              ),
            ),
            Text(
              persona.id,
              style: SyTheme.mono(11,
                  selected ? SyTheme.inkSoft : SyTheme.faint),
            ),
          ],
        ),
      ),
    );
  }
}
