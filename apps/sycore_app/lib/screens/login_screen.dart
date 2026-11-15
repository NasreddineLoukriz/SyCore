import 'package:flutter/material.dart';

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
    if (ok && mounted) {
      setState(() => _create = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              color: SyTheme.surface,
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _Brand(),
                  const SizedBox(height: 36),
                  Text('Encrypted storage you can see.',
                      style: SyTheme.h1.copyWith(fontSize: 30, height: 1.2)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 460,
                    child: Text(
                      'The server stores sealed boxes and a list of who may open '
                      'them. It never holds a key. This app is the client: every '
                      'encryption happens here, before anything is sent.',
                      style: SyTheme.body.copyWith(color: SyTheme.muted),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _Flow(),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Sign in', style: SyTheme.h1),
                      const SizedBox(height: 6),
                      Text(
                        'Each person has their own vault on this machine. '
                        'Pick one — the passphrase is the only thing that unlocks it.',
                        style: SyTheme.small,
                      ),
                      const SizedBox(height: 22),
                      for (final p in personas) ...[
                        _PersonaTile(
                          persona: p,
                          selected: p.id == _who.id,
                          onTap: () => setState(() => _who = p),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 18),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        onSubmitted: (_) => _go(),
                        decoration: const InputDecoration(
                          labelText: 'Passphrase',
                          prefixIcon: Icon(Icons.key_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Argon2id · 64 MiB · 3 iterations — about 0.75 s, on purpose',
                        style: SyTheme.mono(11.5, SyTheme.muted),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: s.busy ? null : _go,
                        icon: s.busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.lock_open, size: 18),
                        label: Text(s.busy
                            ? 'Unlocking…'
                            : (_create
                                ? 'Create identity'
                                : 'Unlock ${_who.name}’s vault')),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: s.busy
                            ? null
                            : () => setState(() => _create = !_create),
                        child: Text(
                          _create
                              ? 'This device already has an envelope — just unlock'
                              : 'First time on this device? Create the identity',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      if (s.error != null) ...[
                        const SizedBox(height: 10),
                        ErrorBanner(s.error!),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.dns_outlined,
                              size: 14,
                              color: s.online ? SyTheme.ok : SyTheme.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.online
                                  ? 'server ${s.server} · reachable'
                                  : 'server ${s.server} · not reachable — start server/run.sh',
                              style: SyTheme.mono(11.5,
                                  s.online ? SyTheme.muted : SyTheme.danger),
                            ),
                          ),
                          IconButton(
                            onPressed: s.ping,
                            icon: const Icon(Icons.refresh, size: 16),
                            tooltip: 'Re-check the server',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SyTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: SyTheme.accent.withValues(alpha: 0.5)),
          ),
          child: const Icon(Icons.shield_outlined, color: SyTheme.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SYCORE',
                style: SyTheme.h1.copyWith(letterSpacing: 4, fontSize: 20)),
            Text('wire format v1', style: SyTheme.mono(11.5, SyTheme.muted)),
          ],
        ),
      ],
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('plaintext', 'this device only', SyTheme.accent),
      ('AES-256-GCM + AAD', 'bound to project · domain · row · owner · version', SyTheme.violet),
      ('ciphertext + wraps[]', 'what leaves the device', SyTheme.muted),
      ('server', 'stores, authorises, never decrypts', SyTheme.warn),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: rows[i].$3,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 170,
                child: Text(rows[i].$1,
                    style: TextStyle(
                        color: rows[i].$3,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              Expanded(
                child: Text(rows[i].$2,
                    style: SyTheme.mono(11.5, SyTheme.muted)),
              ),
            ],
          ),
          if (i < rows.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 3.5),
              child: Container(
                  width: 1, height: 12, color: SyTheme.line),
            ),
        ],
      ],
    );
  }
}

class _PersonaTile extends StatelessWidget {
  const _PersonaTile({
    required this.persona,
    required this.selected,
    required this.onTap,
  });

  final Persona persona;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Color(persona.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.10) : SyTheme.surface,
          border: Border.all(
              color: selected ? c.withValues(alpha: 0.65) : SyTheme.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: c.withValues(alpha: 0.18),
              child: Text(persona.name[0],
                  style: TextStyle(
                      color: c, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(persona.name, style: SyTheme.h2.copyWith(fontSize: 13.5)),
                  Text(persona.role, style: SyTheme.mono(11, SyTheme.muted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 16, color: c)
            else
              Text(persona.id, style: SyTheme.mono(11, SyTheme.line)),
          ],
        ),
      ),
    );
  }
}

/// Used by the shell too.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => const _Brand();
}
