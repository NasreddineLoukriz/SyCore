import 'package:flutter/material.dart';
import 'package:sycore_client/sycore_client.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({super.key, required this.state});

  final AppState state;

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  Map<String, dynamic> stats = const {};
  List<List<ResourceMeta>> byDomain = const [];
  List<Map<String, dynamic>> audit = const [];
  Map<String, dynamic>? wire;
  ResourceMeta? selected;
  String? localError;
  bool loading = true;

  AppState get s => widget.state;
  static const domains = ['health', 'expenses', 'blog'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final health = await s.sdk.operator.health();
      final rows = <List<ResourceMeta>>[];
      for (final d in domains) {
        rows.add(await s.sdk.operator.rows(
            project: AppState.project, domain: d, as: s.userId));
      }
      final a = await s.sdk.operator.audit(limit: 80);
      if (mounted) {
        setState(() {
          stats = (health['stats'] as Map).cast<String, dynamic>();
          byDomain = rows;
          audit = a;
          localError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => localError = s.describe(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _inspect(ResourceMeta m) async {
    setState(() {
      selected = m;
      wire = null;
    });
    try {
      final env = await s.sdk.hosn.envelopeOf(m.id);
      final j = Map<String, dynamic>.from(env.toJson());
      final ct = j['ciphertext'] as String? ?? '';
      j['ciphertext'] = ct.length <= 160 ? ct : '${ct.substring(0, 160)}…';
      j['wraps'] = (j['wraps'] as List)
          .map((w) {
            final m2 = Map<String, dynamic>.from(w as Map);
            final c = m2['ct'] as String;
            m2['ct'] = c.length <= 48 ? c : '${c.substring(0, 48)}…';
            return m2;
          })
          .toList();
      if (mounted) setState(() => wire = j);
    } catch (e) {
      if (mounted) setState(() => localError = s.describe(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (localError != null) ErrorBanner(localError!),
        Row(
          children: [
            _Stat('identities', stats['identities'], SyTheme.violet),
            const SizedBox(width: 10),
            _Stat('resources', stats['resources'], SyTheme.accent),
            const SizedBox(width: 10),
            _Stat('wraps', stats['wraps'], SyTheme.ok),
            const SizedBox(width: 10),
            _Stat('domains', stats['domains'], SyTheme.warn),
            const SizedBox(width: 10),
            _Stat('audit rows', stats['audit'], SyTheme.muted),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Panel(
                title: 'Rows in the database',
                trailing: IconButton(
                    onPressed: _load, icon: const Icon(Icons.refresh, size: 17)),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < domains.length; i++) ...[
                            Text(domains[i].toUpperCase(),
                                style: SyTheme.mono(10.5, SyTheme.muted)
                                    .copyWith(letterSpacing: 1.4)),
                            const SizedBox(height: 6),
                            if (byDomain[i].isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text('— empty —', style: SyTheme.small),
                              )
                            else
                              for (final m in byDomain[i])
                                InkWell(
                                  onTap: () => _inspect(m),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 5),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: selected?.id == m.id
                                          ? SyTheme.accent.withValues(alpha: 0.08)
                                          : SyTheme.surfaceAlt,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: selected?.id == m.id
                                              ? SyTheme.accent.withValues(alpha: 0.45)
                                              : SyTheme.line),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(m.id,
                                              style: SyTheme.mono(11.5, SyTheme.text)),
                                        ),
                                        Text(
                                          '${m.readers.length} readers · '
                                          '${m.ciphertextChars} chars',
                                          style: SyTheme.mono(10.5, SyTheme.muted),
                                        ),
                                        const SizedBox(width: 8),
                                        if (m.signed)
                                          const Pill('signed', color: SyTheme.ok)
                                        else
                                          const Pill('sealed', color: SyTheme.accent),
                                      ],
                                    ),
                                  ),
                                ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Panel(
                    title: selected == null
                        ? 'Wire view'
                        : 'Wire view · ${selected!.id}',
                    child: wire == null
                        ? const EmptyState(
                            'Select a row.\nThis is what the operator can read.',
                            icon: Icons.data_object)
                        : MonoBlock(AppState.prettyJson(wire!), maxHeight: 320),
                  ),
                  const SizedBox(height: 14),
                  Panel(
                    title: 'Audit',
                    child: SizedBox(
                      height: 220,
                      child: ListView(
                        children: [
                          for (final e in audit)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 54,
                                    child: Text(stamp(e['at'] as String),
                                        style: SyTheme.mono(10.5)),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${e['action']}',
                                      style: SyTheme.mono(
                                        11,
                                        (e['action'] as String).contains('denied') ||
                                                (e['action'] as String)
                                                    .contains('rejected')
                                            ? SyTheme.danger
                                            : SyTheme.text,
                                      ),
                                    ),
                                  ),
                                  Text('${e['actor']}',
                                      style: SyTheme.mono(10.5, SyTheme.muted)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'The point',
          child: Text(
            'Everything above is metadata: who owns a row, who may read it, '
            'when, how large. The ciphertext column is the only thing that '
            'matters, and no endpoint returns it to a user who is not in its '
            'wraps. There is no admin route that decrypts, because there is no '
            'key to decrypt with.',
            style: SyTheme.body.copyWith(color: SyTheme.muted),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final Object? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: SyTheme.surface,
          border: Border.all(color: SyTheme.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${value ?? 0}',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: SyTheme.mono(10.5)),
          ],
        ),
      ),
    );
  }
}
