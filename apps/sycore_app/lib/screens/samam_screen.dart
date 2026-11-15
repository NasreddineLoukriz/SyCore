import 'package:flutter/material.dart';
import 'package:sycore_client/sycore_client.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class SamamScreen extends StatefulWidget {
  const SamamScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SamamScreen> createState() => _SamamScreenState();
}

class _SamamScreenState extends State<SamamScreen> {
  static const domain = 'expenses';
  static const groupId = 'grp_family';

  GroupInfo? group;
  List<ResourceMeta> rows = const [];
  bool loading = true;
  String? noteKey;
  Map<String, Object?> noteVars = const {};
  String? _errKey;
  Map<String, Object?> _errVars = const {};
  String? openId;
  String? opened;

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

  void _note(String key, [Map<String, Object?>? vars]) => setState(() {
        noteKey = key;
        noteVars = vars ?? const {};
      });

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      GroupInfo? g;
      try {
        g = await s.sdk.samam.get(groupId);
      } on SycoreException {
        g = null;
      }
      final r =
          await s.sdk.hosn.inbox(project: AppState.project, domain: domain);
      if (mounted) {
        setState(() {
          group = g;
          rows = r;
        });
      }
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _createGroup() async {
    final t = context.s;
    final chosen = <String>{'usr_sara', 'usr_mona'}..remove(s.userId);
    final ok = await showSheet(
      context,
      title: t.t('new_group'),
      note: t.t('new_group_note'),
      confirmLabel: t.t('create'),
      body: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          children: [
            for (final p in personas)
              if (p.id != s.userId)
                InkWell(
                  onTap: () => setLocal(() {
                    if (chosen.contains(p.id)) {
                      chosen.remove(p.id);
                    } else {
                      chosen.add(p.id);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: chosen.contains(p.id),
                          onChanged: (v) => setLocal(() {
                            if (v == true) {
                              chosen.add(p.id);
                            } else {
                              chosen.remove(p.id);
                            }
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nameIn(t),
                                  style: Theme.of(ctx).textTheme.titleSmall),
                              Text(t.t(p.roleKey),
                                  style: Theme.of(ctx).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text(p.id, style: SyTheme.mono(11, SyTheme.faint)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final g = await s.guard(() => s.sdk.samam.create(
          id: groupId,
          project: AppState.project,
          domain: domain,
          members: chosen.toList(),
        ));
    if (g != null) {
      _note('group_created', {'n': g.epoch});
      await _load();
    }
  }

  Future<void> _post() async {
    final t = context.s;
    final text = TextEditingController(text: 'March budget: 41,000 DZD');
    final ok = await showSheet(
      context,
      title: t.t('post_to_epoch', {'n': group?.epoch}),
      note: t.t('new_group_note'),
      confirmLabel: t.t('seal_post'),
      body: TextField(
        controller: text,
        maxLines: 3,
        decoration: InputDecoration(labelText: t.t('message')),
      ),
    );
    if (ok != true) return;
    final epoch = group?.epoch;
    final env = await s.guard(() =>
        s.sdk.samam.post(groupId: groupId, text: text.text));
    if (env != null) {
      _note('group_posted', {'n': epoch, 'w': env.readerCount});
      await _load();
    }
  }

  Future<void> _remove(String userId) async {
    final g = await s.guard(() => s.sdk.samam.removeMember(groupId, userId));
    if (g == null) return;
    _note('member_removed', {'user': userId, 'n': g.epoch});
    await _load();
  }

  Future<void> _add(String userId) async {
    final g = await s.guard(() => s.sdk.samam.addMember(groupId, userId));
    if (g == null) return;
    _note('member_added', {'user': userId, 'n': g.epoch});
    await _load();
  }

  Future<void> _open(ResourceMeta m) async {
    setState(() {
      openId = m.id;
      opened = null;
      _errKey = null;
    });
    try {
      final text = await s.sdk.samam.open(m.id);
      if (mounted) setState(() => opened = text);
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tx = Theme.of(context).textTheme;
    final g = group;

    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 48),
      children: [
        PageHead(
          title: t.t('nav_group'),
          blurb: t.t('nav_blurb_group'),
          actions: [
            if (g != null) Tag('${t.t('epoch')} ${g.epoch}', color: SyTheme.warn),
            if (g != null && s.userId == 'usr_ali')
              OutlinedButton(
                onPressed: _post,
                child: Text(t.t('post_to_epoch', {'n': g.epoch})),
              ),
          ],
        ),
        if (s.error(t) != null) ...[
          Note(s.error(t)!, kind: NoteKind.danger),
          const SizedBox(height: 22),
        ],
        if (_errKey != null) ...[
          Note(t.t(_errKey!, _errVars), kind: NoteKind.danger),
          const SizedBox(height: 22),
        ],
        if (noteKey != null) ...[
          Note(t.t(noteKey!, noteVars), kind: NoteKind.ok),
          const SizedBox(height: 22),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── membership ──────────────────────────────────────
            Expanded(
              flex: 4,
              child: Section(
                first: true,
                title: t.t('group'),
                child: g == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(t.t('no_group'), style: tx.bodySmall),
                          if (s.userId == 'usr_ali') ...[
                            const SizedBox(height: 16),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: OutlinedButton(
                                onPressed: _createGroup,
                                child: Text(t.t('create_group')),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Field(t.t('epoch'), '${g.epoch}', mono: true),
                          Field(t.t('members'), '${g.memberIds.length}',
                              mono: true),
                          const SizedBox(height: 10),
                          Text(t.t('members'), style: tx.labelMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final id in g.memberIds)
                                _Member(
                                  label: _nameOf(id, t),
                                  mine: id == s.userId,
                                  onRemove: (id == s.userId ||
                                          s.userId != 'usr_ali')
                                      ? null
                                      : () => _remove(id),
                                ),
                              for (final p in personas)
                                if (!g.members.containsKey(p.id) &&
                                    s.userId == 'usr_ali')
                                  TextButton(
                                    onPressed: () => _add(p.id),
                                    child: Text(
                                      t.t('add_member', {'user': p.id}),
                                      style: SyTheme.mono(11,
                                          SyTheme.accent),
                                    ),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(t.t('member_note'), style: tx.bodySmall),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 56),
            // ── timeline ────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Section(
                first: true,
                title: t.t('timeline'),
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  tooltip: t.t('refresh'),
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: LinearProgressIndicator(),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (rows.isEmpty)
                            Blank(s.userId == 'usr_mona'
                                ? t.t('mona_empty')
                                : t.t('no_messages')),
                          for (final m in rows) ...[
                            InkWell(
                              onTap: () => _open(m),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 11, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: openId == m.id
                                      ? SyTheme.accentSoft
                                      : null,
                                  border: const Border(
                                    bottom: BorderSide(
                                        color: SyTheme.lineSoft),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(m.id,
                                              style: SyTheme.mono(11.5,
                                                  SyTheme.ink)),
                                        ),
                                        Text(
                                          t.t('readers_n',
                                              {'n': m.readers.length}),
                                          style: tx.labelSmall,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(stamp(m.updatedAt),
                                            style: tx.labelSmall),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      m.readers.join(' · '),
                                      style: SyTheme.mono(10.5, SyTheme.faint),
                                    ),
                                    if (openId == m.id) ...[
                                      if (opened != null) ...[
                                        const SizedBox(height: 10),
                                        Text(opened!,
                                            style: tx.bodyMedium?.copyWith(
                                                color: SyTheme.ink)),
                                      ] else if (_errKey != null) ...[
                                        const SizedBox(height: 8),
                                        Text(t.t(_errKey!, _errVars),
                                            style: tx.bodySmall?.copyWith(
                                                color: SyTheme.danger)),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
        Section(
          title: t.t('removal_title'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(t.t('removal_note'), style: tx.bodyMedium),
          ),
        ),
      ],
    );
  }

  String _nameOf(String id, Strings t) {
    final p = personas.where((p) => p.id == id).firstOrNull;
    return p == null ? id : '${p.nameIn(t)} · $id';
  }
}

class _Member extends StatelessWidget {
  const _Member({required this.label, required this.mine, this.onRemove});

  final String label;
  final bool mine;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border.all(color: SyTheme.line),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: tx.labelSmall?.copyWith(color: SyTheme.inkSoft)),
          if (onRemove != null)
            InkWell(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close, size: 12, color: SyTheme.danger),
              ),
            ),
        ],
      ),
    );
  }
}
