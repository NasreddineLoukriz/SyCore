import 'package:flutter/material.dart';
import 'package:sycore_client/sycore_client.dart';

import '../l10n.dart';
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
  bool busy = false;
  String? _errKey;
  Map<String, Object?> _errVars = const {};

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _fail(Object e) {
    final d = s.describe(e);
    setState(() {
      _errKey = d.$1;
      _errVars = d.$2;
    });
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r =
          await s.sdk.hosn.inbox(project: AppState.project, domain: domain);
      if (mounted) setState(() => rows = r);
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _open(ResourceMeta m) async {
    setState(() {
      selected = m;
      plain = null;
      wire = null;
      _errKey = null;
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
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _compose() async {
    final t = context.s;
    final to = ValueNotifier<String>(
        personas.firstWhere((p) => p.id != s.userId).id);
    final text = TextEditingController(
        text: 'Surgery: 15 January, 8:30, Mustapha Pacha');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('compose_title')),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.t('compose_note'),
                  style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 18),
              ValueListenableBuilder<String>(
                valueListenable: to,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  initialValue: v,
                  decoration: InputDecoration(labelText: t.t('to')),
                  dropdownColor: SyTheme.raised,
                  items: [
                    for (final p in personas)
                      if (p.id != s.userId)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.nameIn(t)} · ${p.id}'),
                        ),
                  ],
                  onChanged: (x) => to.value = x ?? v,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: text,
                maxLines: 4,
                decoration: InputDecoration(labelText: t.t('message')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.t('encrypt_send')),
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
      if (mounted) setState(() => _errKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tx = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 30, 40, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHead(
                title: t.t('nav_messages'),
                blurb: t.t('nav_blurb_messages'),
                actions: [
                  Tag('$domain · ${t.t('domain_health')}'),
                  OutlinedButton(
                    onPressed: _compose,
                    child: Text(t.t('new_message')),
                  ),
                ],
              ),
              if (s.error(t) != null) ...[
                Note(s.error(t)!, kind: NoteKind.danger),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── the inbox ───────────────────────────────────
                SizedBox(
                  width: 350,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 40),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${t.t('inbox')} · $domain',
                                style: tx.labelMedium),
                          ),
                          IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, size: 16),
                            tooltip: t.t('refresh'),
                          ),
                        ],
                      ),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: LinearProgressIndicator(),
                        )
                      else if (rows.isEmpty)
                        Blank(t.t('empty_inbox'))
                      else
                        for (final m in rows)
                          RowLine(
                            onTap: () => _open(m),
                            selected: selected?.id == m.id,
                            trailing: Text(stamp(m.updatedAt),
                                style: tx.labelSmall),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.id,
                                    style: SyTheme.mono(11.5, SyTheme.ink)),
                                const SizedBox(height: 3),
                                Text(
                                  t.t('from_to', {
                                    'from': m.ownerId,
                                    'to': m.readers
                                        .where((r) => r != m.ownerId)
                                        .join(', '),
                                  }),
                                  style: tx.labelSmall,
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsetsDirectional.only(start: 28, end: 32),
                  height: double.infinity,
                  color: SyTheme.lineSoft,
                ),
                // ── the row ─────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 40),
                    children: [
                      if (selected == null) ...[
                        const SizedBox(height: 6),
                        Text(t.t('open_a_row'), style: tx.headlineSmall),
                        const SizedBox(height: 8),
                        Text(t.t('open_hint'), style: tx.bodySmall),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(selected!.id,
                                  style: SyTheme.mono(13, SyTheme.ink)),
                            ),
                            Tag(
                              plain != null
                                  ? t.t('opened_locally')
                                  : (_errKey != null
                                      ? t.t('refused')
                                      : '…'),
                              color: plain != null
                                  ? SyTheme.ok
                                  : SyTheme.danger,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (_errKey != null) ...[
                          Note(t.t(_errKey!, _errVars),
                              kind: NoteKind.danger),
                          const SizedBox(height: 20),
                        ],
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: LinearProgressIndicator(),
                          ),
                        if (plain != null) ...[
                          Text(t.t('plaintext'), style: tx.labelSmall),
                          const SizedBox(height: 8),
                          Container(
                            decoration: const BoxDecoration(
                              border: BorderDirectional(
                                start: BorderSide(
                                    color: SyTheme.accent, width: 2),
                              ),
                            ),
                            padding: const EdgeInsetsDirectional.only(
                                start: 14, top: 2, bottom: 2),
                            child: SelectableText(
                              plain!,
                              style: tx.bodyLarge?.copyWith(
                                fontSize: (tx.bodyLarge?.fontSize ?? 15) + 1,
                                color: SyTheme.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Section(
                            title: t.t('as_stored'),
                            child: wire == null
                                ? const SizedBox.shrink()
                                : Code(AppState.prettyJson(
                                    Map<String, dynamic>.from(wire!))),
                          ),
                        ],
                        Section(
                          first: plain == null,
                          title: t.t('metadata'),
                          child: Column(
                            children: [
                              Field(t.t('owner'), selected!.ownerId,
                                  mono: true),
                              Field(t.t('readers'),
                                  selected!.readers.join(', '),
                                  mono: true),
                              Field(t.t('wraps'),
                                  '${selected!.readers.length}',
                                  mono: true),
                              Field(t.t('ciphertext'),
                                  t.t('chars', {'n': selected!.ciphertextChars}),
                                  mono: true),
                              Field(t.t('version'),
                                  t.t('v', {'n': selected!.version}),
                                  mono: true),
                              Field(t.t('updated'),
                                  stamp(selected!.updatedAt), mono: true),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
