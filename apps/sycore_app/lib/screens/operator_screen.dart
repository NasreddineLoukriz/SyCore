import 'package:flutter/material.dart';
import 'package:sycore_client/sycore_client.dart';

import '../l10n.dart';
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
  static const domains = ['health', 'expenses', 'blog'];

  Map<String, dynamic> stats = const {};
  List<List<ResourceMeta>> byDomain = const [];
  List<Map<String, dynamic>> audit = const [];
  Map<String, dynamic>? wire;
  ResourceMeta? selected;
  String? _errKey;
  Map<String, Object?> _errVars = const {};
  bool loading = true;

  AppState get s => widget.state;

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
          _errKey = null;
        });
      }
    } catch (e) {
      final d = s.describe(e);
      if (mounted) {
        setState(() {
          _errKey = d.$1;
          _errVars = d.$2;
        });
      }
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
      j['wraps'] = (j['wraps'] as List).map((w) {
        final m2 = Map<String, dynamic>.from(w as Map);
        final c = m2['ct'] as String;
        m2['ct'] = c.length <= 48 ? c : '${c.substring(0, 48)}…';
        return m2;
      }).toList();
      if (mounted) setState(() => wire = j);
    } catch (e) {
      final d = s.describe(e);
      if (mounted) {
        setState(() {
          _errKey = d.$1;
          _errVars = d.$2;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tx = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 48),
      children: [
        PageHead(
          title: t.t('nav_operator'),
          blurb: t.t('nav_blurb_operator'),
          actions: [
            Tag(AppState.project),
            OutlinedButton(
              onPressed: _load,
              child: Text(t.t('refresh')),
            ),
          ],
        ),
        if (_errKey != null) ...[
          Note(t.t(_errKey!, _errVars), kind: NoteKind.danger),
          const SizedBox(height: 22),
        ],
        Row(
          children: [
            _Figure('${stats['identities'] ?? 0}', t.t('stats_identities')),
            _Figure('${stats['resources'] ?? 0}', t.t('stats_resources')),
            _Figure('${stats['wraps'] ?? 0}', t.t('stats_wraps')),
            _Figure('${stats['domains'] ?? 0}', t.t('stats_domains')),
            _Figure('${stats['audit'] ?? 0}', t.t('stats_audit')),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── rows ────────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Section(
                first: true,
                title: t.t('rows_in_db'),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: LinearProgressIndicator(),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < domains.length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                domains[i],
                                style: SyTheme.mono(10.5, SyTheme.faint),
                              ),
                            ),
                            if (byDomain[i].isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(t.t('empty'),
                                    style: tx.bodySmall
                                        ?.copyWith(color: SyTheme.faint)),
                              )
                            else
                              for (final m in byDomain[i])
                                RowLine(
                                  onTap: () => _inspect(m),
                                  selected: selected?.id == m.id,
                                  trailing: m.signed
                                      ? Tag(t.t('signed'), color: SyTheme.ok)
                                      : Tag(t.t('sealed'),
                                          color: SyTheme.accent),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(m.id,
                                          style: SyTheme.mono(
                                              11.5, SyTheme.ink)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${t.t('readers_n', {'n': m.readers.length})}'
                                        ' · ${t.t('chars', {'n': m.ciphertextChars})}',
                                        style: tx.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 56),
            // ── wire + audit ────────────────────────────────────
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Section(
                    first: true,
                    title: t.t('wire_view'),
                    child: wire == null
                        ? Blank(t.t('wire_hint'))
                        : Code(AppState.prettyJson(wire!), maxHeight: 320),
                  ),
                  Section(
                    title: t.t('audit'),
                    child: SizedBox(
                      height: 220,
                      child: ListView(
                        children: [
                          for (final e in audit)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 58,
                                    child: Text(
                                      stamp(e['at'] as String),
                                      style: tx.labelSmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${e['action']}',
                                      style: SyTheme.mono(
                                        11,
                                        (e['action'] as String)
                                                    .contains('denied') ||
                                                (e['action'] as String)
                                                    .contains('rejected')
                                            ? SyTheme.danger
                                            : SyTheme.inkSoft,
                                      ),
                                    ),
                                  ),
                                  Text('${e['actor']}',
                                      style: tx.labelSmall),
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
        Section(
          title: t.t('the_point'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Text(t.t('the_point_note'), style: tx.bodyMedium),
          ),
        ),
      ],
    );
  }
}

/// A number and its name, separated by hairlines rather than boxes.
class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: SyTheme.lineSoft),
          ),
        ),
        padding: const EdgeInsetsDirectional.only(start: 14, top: 2, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: SyTheme.display(22, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: tx.labelSmall),
          ],
        ),
      ),
    );
  }
}
