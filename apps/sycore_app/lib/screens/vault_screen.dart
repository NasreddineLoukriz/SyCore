import 'package:flutter/material.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, required this.state});

  final AppState state;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  List<String> devices = const [];
  bool _showEnvelope = false;
  String? _noteKey;
  Map<String, Object?> _noteVars = const {};

  AppState get s => widget.state;
  Strings get t => context.s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await s.sdk.vault.devices();
      if (mounted) setState(() => devices = d);
    } catch (_) {}
  }

  void _note(String key, [Map<String, Object?>? vars]) =>
      setState(() {
        _noteKey = key;
        _noteVars = vars ?? const {};
      });

  Future<void> _addDevice() async {
    final t = this.t;
    final name = TextEditingController(text: 'phone');
    final pass = TextEditingController(text: AppState.demoPassword);
    final ok = await showSheet(
      context,
      title: t.t('add_device'),
      note: t.t('add_device_note'),
      confirmLabel: t.t('add'),
      body: Column(
        children: [
          TextField(
            controller: name,
            decoration: InputDecoration(labelText: t.t('device_name')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: pass,
            obscureText: true,
            decoration: InputDecoration(labelText: t.t('passphrase')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await s.guard(() async {
      await s.sdk.vault.addDevice(name.text.trim(), pass.text);
      return true;
    });
    if (done == true) {
      await _load();
      _note('device_added', {'name': name.text.trim()});
    }
  }

  Future<void> _changePassword() async {
    final t = this.t;
    final old = TextEditingController(text: AppState.demoPassword);
    final next = TextEditingController(text: 'a new passphrase');
    final ok = await showSheet(
      context,
      title: t.t('change_passphrase'),
      note: t.t('change_passphrase_note'),
      confirmLabel: t.t('rewrap'),
      body: Column(
        children: [
          TextField(
            controller: old,
            obscureText: true,
            decoration: InputDecoration(labelText: t.t('current')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: next,
            obscureText: true,
            decoration: InputDecoration(labelText: t.t('new')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await s.guard(() async {
      await s.sdk.vault.changePassword(old.text, next.text);
      return true;
    });
    if (done == true) _note('passphrase_changed');
  }

  @override
  Widget build(BuildContext context) {
    final a = s.account!;
    final t = context.s;
    final tx = Theme.of(context).textTheme;
    final envelope = Map<String, dynamic>.from(s.sdk.vault.envelope);

    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 48),
      children: [
        PageHead(
          title: t.t('nav_vault'),
          blurb: t.t('nav_blurb_vault'),
          actions: [
            Tag(a.deviceId, color: SyTheme.accent),
            Tag(a.userId),
          ],
        ),
        if (s.error(t) != null) ...[
          Note(s.error(t)!, kind: NoteKind.danger),
          const SizedBox(height: 22),
        ],
        if (_noteKey != null) ...[
          Note(t.t(_noteKey!, _noteVars), kind: NoteKind.ok),
          const SizedBox(height: 22),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Section(
                first: true,
                title: t.t('identity'),
                note: t.t('identity_note'),
                child: Column(
                  children: [
                    Field(t.t('user'), a.userId, mono: true),
                    Field(t.t('device'), a.deviceId, mono: true),
                    Field(t.t('fingerprint'), a.fingerprint, mono: true),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 56),
            Expanded(
              child: Section(
                first: true,
                title: t.t('vault_key'),
                trailing: TextButton(
                  onPressed: _changePassword,
                  child: Text(t.t('change')),
                ),
                note: t.t('vault_key_note'),
                child: Column(
                  children: [
                    Field(t.t('vk'), s.sdk.vault.vaultKeyPreview, mono: true),
                    Field(t.t('derivation'), t.t('derivation_value')),
                    Field(t.t('wrapped_by'), t.t('wrapped_by_value')),
                  ],
                ),
              ),
            ),
          ],
        ),
        Section(
          title: t.t('devices'),
          trailing: TextButton(
            onPressed: _addDevice,
            child: Text(t.t('add_device_short')),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final d in devices)
                RowLine(
                  onTap: null,
                  selected: d == a.deviceId,
                  child: Row(
                    children: [
                      Text(d, style: SyTheme.mono(12.5, SyTheme.ink)),
                      const SizedBox(width: 10),
                      if (d == a.deviceId)
                        Tag(t.t('this_one'), color: SyTheme.accent),
                    ],
                  ),
                ),
              if (devices.isEmpty) Blank(t.t('no_envelope')),
            ],
          ),
        ),
        Section(
          title: t.t('server_holds'),
          trailing: TextButton(
            onPressed: () => setState(() => _showEnvelope = !_showEnvelope),
            child: Text(_showEnvelope ? t.t('hide') : t.t('show_json')),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.t('server_holds_note'), style: tx.bodySmall),
              if (_showEnvelope) ...[
                const SizedBox(height: 14),
                Code(AppState.prettyJson(envelope)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

