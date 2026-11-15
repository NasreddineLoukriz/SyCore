import 'package:flutter/material.dart';

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
  String? _note;

  AppState get s => widget.state;

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

  Future<void> _addDevice() async {
    final name = TextEditingController(text: 'phone');
    final pass = TextEditingController(text: AppState.demoPassword);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SyTheme.surface,
        title: const Text('Add a device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A new envelope around the same vault key. No message is '
              're-encrypted, and this device keeps its own Argon2id salt.',
              style: SyTheme.small,
            ),
            const SizedBox(height: 14),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Device name')),
            const SizedBox(height: 10),
            TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Passphrase')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
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
      setState(() => _note =
          'Device “${name.text.trim()}” now holds its own envelope for the same VK.');
    }
  }

  Future<void> _changePassword() async {
    final old = TextEditingController(text: AppState.demoPassword);
    final next = TextEditingController(text: 'a new passphrase');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SyTheme.surface,
        title: const Text('Change passphrase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The vault key is re-wrapped under the new passphrase. Not one '
              'content key, and not one ciphertext, is touched.',
              style: SyTheme.small,
            ),
            const SizedBox(height: 14),
            TextField(
                controller: old,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current')),
            const SizedBox(height: 10),
            TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-wrap')),
        ],
      ),
    );
    if (ok != true) return;
    final done = await s.guard(() async {
      await s.sdk.vault.changePassword(old.text, next.text);
      return true;
    });
    if (done == true) {
      setState(() => _note = 'Passphrase changed. The VK is byte-identical.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = s.account!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (s.error != null) ErrorBanner(s.error!),
        if (_note != null) ...[OkBanner(_note!), const SizedBox(height: 14)],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Panel(
                title: 'Identity',
                child: Column(
                  children: [
                    Kv('user', a.userId, mono: true),
                    Kv('device', a.deviceId, mono: true),
                    Kv('fingerprint', a.fingerprint, mono: true),
                    const Divider(height: 22),
                    Text(
                      'Two key pairs are held by this device: X25519 for key '
                      'agreement and Ed25519 for signatures. Only the public '
                      'halves were ever sent to the server.',
                      style: SyTheme.small,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Panel(
                title: 'Vault key',
                child: Column(
                  children: [
                    Kv('VK', s.sdk.vault.vaultKeyPreview, mono: true),
                    Kv('derivation', 'Argon2id (t=3, m=64 MiB, p=4) → KEK', mono: true),
                    Kv('wrapped by', 'AES-256-GCM, AAD = device id', mono: true),
                    const Divider(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'This key never leaves the process. The server stores '
                            'the envelope next to it, not the key.',
                            style: SyTheme.small,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _changePassword,
                          icon: const Icon(Icons.password, size: 15),
                          label: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Panel(
                title: 'Devices',
                trailing: IconButton(
                  onPressed: _addDevice,
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Add a device',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in devices)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              d == a.deviceId
                                  ? Icons.laptop_mac
                                  : Icons.smartphone,
                              size: 16,
                              color: d == a.deviceId
                                  ? SyTheme.accent
                                  : SyTheme.muted,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                                child: Text(d, style: SyTheme.mono(12.5))),
                            if (d == a.deviceId)
                              const Pill('this one', color: SyTheme.accent),
                          ],
                        ),
                      ),
                    if (devices.isEmpty) const EmptyState('no envelope here'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'What the server holds for this device',
          trailing: TextButton(
            onPressed: () => setState(() => _showEnvelope = !_showEnvelope),
            child: Text(_showEnvelope ? 'Hide' : 'Show JSON'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A salt, a nonce, and a wrapped vault key. Three fields that are '
                'useless without the passphrase — and the passphrase is never sent.',
                style: SyTheme.small,
              ),
              if (_showEnvelope) ...[
                const SizedBox(height: 12),
                MonoBlock(AppState.prettyJson(
                    s.sdk.vault.envelope.map((k, v) => MapEntry(k, v)))),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
