import 'package:flutter/material.dart';
import 'package:sycore_client/sycore_client.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class HosnScreen extends StatefulWidget {
  const HosnScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HosnScreen> createState() => _HosnScreenState();
}

class _HosnScreenState extends State<HosnScreen> {
  static const domain = 'health';

  List<ResourceMeta> rows = const [];
  ResourceMeta? selected;
  String? plain;
  Map<String, dynamic>? wire;
  bool loading = true;
  String? localError;
  bool busy = false;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await s.sdk.hosn
          .inbox(project: AppState.project, domain: domain);
      if (mounted) setState(() => rows = r);
    } catch (e) {
      if (mounted) setState(() => localError = s.describe(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _open(ResourceMeta m) async {
    setState(() {
      selected = m;
      plain = null;
      wire = null;
      localError = null;
      busy = true;
    });
    try {
      final text = await s.sdk.hosn.open(m.id);
      final env = await s.sdk.hosn.envelopeOf(m.id);
      if (mounted) {
        setState(() {
          plain = text;
          wire = env.toJson();
        });
      }
    } catch (e) {
      if (mounted) setState(() => localError = s.describe(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _compose() async {
    final to = ValueNotifier<String>(
        personas.firstWhere((p) => p.id != s.userId).id);
    final text = TextEditingController(text: 'Surgery: 15 January, 8:30, Mustapha Pacha');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SyTheme.surface,
        title: const Text('HOSN · one recipient'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'The content key is written twice: once for you (under the vault '
                'key) and once for the recipient (under X25519). The server sees '
                'two sealed boxes and a list of names.',
                style: SyTheme.small,
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                valueListenable: to,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  initialValue: v,
                  decoration: const InputDecoration(labelText: 'To'),
                  dropdownColor: SyTheme.surfaceAlt,
                  items: [
                    for (final p in personas)
                      if (p.id != s.userId)
                        DropdownMenuItem(value: p.id, child: Text('${p.name} · ${p.id}')),
                  ],
                  onChanged: (x) => to.value = x ?? v,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: text,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Encrypt & send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final env = await s.guard(() => s.sdk.hosn.send(
          to: to.value,
          project: AppState.project,
          domain: domain,
          text: text.text,
        ));
    if (env != null) {
      await _load();
      setState(() => localError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.error != null) ErrorBanner(s.error!),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 380,
                  child: Panel(
                    title: 'Inbox · $domain',
                    trailing: Row(
                      children: [
                        IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, size: 17),
                            tooltip: 'Reload'),
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          onPressed: _compose,
                          icon: const Icon(Icons.add, size: 15),
                          label: const Text('New'),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : rows.isEmpty
                            ? const EmptyState(
                                'No rows this user may see.\nCompose one, or sign in as the recipient.')
                            : Column(
                                children: [
                                  for (final m in rows)
                                    _RowTile(
                                      meta: m,
                                      me: s.userId,
                                      selected: selected?.id == m.id,
                                      onTap: () => _open(m),
                                    ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Panel(
                    title: selected == null
                        ? 'Open a row'
                        : 'Row ${selected!.id}',
                    trailing: selected == null
                        ? null
                        : Pill(
                            plain != null ? 'opened locally' : 'refused',
                            color: plain != null ? SyTheme.ok : SyTheme.danger,
                          ),
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : selected == null
                            ? const EmptyState(
                                'The server returns a sealed box.\nThe key is derived here, not there.',
                                icon: Icons.lock_outline,
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (localError != null) ErrorBanner(localError!),
                                    if (plain != null) ...[
                                      Text('Plaintext, recovered on this device',
                                          style: SyTheme.small),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: SyTheme.accent.withValues(alpha: 0.07),
                                          border: Border.all(
                                              color: SyTheme.accent.withValues(alpha: 0.35)),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: SelectableText(plain!,
                                            style: SyTheme.body.copyWith(fontSize: 15)),
                                      ),
                                      const SizedBox(height: 16),
                                      Text('The same row, as the server stores it',
                                          style: SyTheme.small),
                                      const SizedBox(height: 8),
                                      if (wire != null)
                                        MonoBlock(AppState.prettyJson(
                                            Map<String, dynamic>.from(wire!))),
                                      const SizedBox(height: 16),
                                    ],
                                    Kv('owner', selected!.ownerId, mono: true),
                                    Kv('readers', selected!.readers.join(', '), mono: true),
                                    Kv('wraps', '${selected!.readers.length}', mono: true),
                                    Kv('ciphertext', '${selected!.ciphertextChars} chars', mono: true),
                                    Kv('version', 'v${selected!.version}', mono: true),
                                    Kv('updated', stamp(selected!.updatedAt), mono: true),
                                  ],
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.meta,
    required this.me,
    required this.selected,
    required this.onTap,
  });

  final ResourceMeta meta;
  final String me;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mine = meta.ownerId == me;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? SyTheme.accent.withValues(alpha: 0.10) : SyTheme.surfaceAlt,
          border: Border.all(
              color: selected ? SyTheme.accent.withValues(alpha: 0.5) : SyTheme.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(mine ? Icons.outbox : Icons.inbox,
                    size: 14, color: mine ? SyTheme.accent : SyTheme.violet),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(meta.id,
                      overflow: TextOverflow.ellipsis,
                      style: SyTheme.mono(12, SyTheme.text)),
                ),
                Text(stamp(meta.updatedAt), style: SyTheme.mono(10.5, SyTheme.muted)),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${meta.ownerId} → ${meta.readers.where((r) => r != meta.ownerId).join(', ')}'
              '   ·   ${meta.ciphertextChars} chars',
              style: SyTheme.mono(10.5, SyTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
