import 'package:flutter/material.dart';
import 'package:sycore_client/sycore_client.dart';

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
  String? note;
  String? localError;
  String? openId;
  String? opened;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      GroupInfo? g;
      try {
        g = await s.sdk.samam.get(groupId);
      } on SycoreException {
        g = null;
      }
      final r = await s.sdk.hosn.inbox(project: AppState.project, domain: domain);
      if (mounted) {
        setState(() {
          group = g;
          rows = r;
        });
      }
    } catch (e) {
      if (mounted) setState(() => localError = s.describe(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _createGroup() async {
    final chosen = <String>{'usr_sara', 'usr_mona'}..remove(s.userId);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: SyTheme.surface,
          title: const Text('New group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The epoch key is wrapped once per member. Removing someone '
                'bumps the epoch and replaces the key.',
                style: SyTheme.small,
              ),
              const SizedBox(height: 12),
              for (final p in personas)
                if (p.id != s.userId)
                  CheckboxListTile(
                    value: chosen.contains(p.id),
                    onChanged: (v) => setLocal(() {
                      if (v == true) {
                        chosen.add(p.id);
                      } else {
                        chosen.remove(p.id);
                      }
                    }),
                    title: Text('${p.name} · ${p.id}', style: SyTheme.body),
                    subtitle: Text(p.role, style: SyTheme.mono(10.5)),
                    dense: true,
                    activeColor: SyTheme.accent,
                  ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create')),
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
      setState(() => note = 'Group created at epoch ${g.epoch}.');
      await _load();
    }
  }

  Future<void> _post() async {
    final text = TextEditingController(text: 'March budget: 41,000 DZD');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SyTheme.surface,
        title: Text('Post to epoch ${group?.epoch}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: text,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Seal & post')),
        ],
      ),
    );
    if (ok != true) return;
    final env = await s.guard(() => s.sdk.samam.post(
          groupId: groupId,
          text: text.text,
        ));
    if (env != null) {
      setState(() => note = 'Sealed with epoch ${group!.epoch} key · '
          '${env.readerCount} wraps.');
      await _load();
    }
  }

  Future<void> _remove(String userId) async {
    final g = await s.guard(() => s.sdk.samam.removeMember(groupId, userId));
    if (g == null) return;
    setState(() {
      note = '$userId removed → epoch ${g.epoch}. The key was replaced: '
          'the past stays readable, the future does not.';
    });
    await _load();
  }

  Future<void> _add(String userId) async {
    final g = await s.guard(() => s.sdk.samam.addMember(groupId, userId));
    if (g == null) return;
    setState(() => note = '$userId added → epoch ${g.epoch}.');
    await _load();
  }

  Future<void> _open(ResourceMeta m) async {
    setState(() {
      openId = m.id;
      opened = null;
      localError = null;
    });
    try {
      final t = await s.sdk.samam.open(m.id);
      if (mounted) setState(() => opened = t);
    } catch (e) {
      if (mounted) setState(() => localError = s.describe(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final removable = personas.where((p) => p.id != s.userId).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (s.error != null) ErrorBanner(s.error!),
        if (localError != null) ErrorBanner(localError!),
        if (note != null) ...[OkBanner(note!, color: SyTheme.violet), const SizedBox(height: 14)],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Panel(
                title: 'Group',
                trailing: group == null
                    ? null
                    : Pill('epoch ${group!.epoch}', color: SyTheme.violet),
                child: group == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const EmptyState(
                            'No group state on this device.\nOnly the creator holds the epoch key.',
                            icon: Icons.groups_outlined,
                          ),
                          if (s.userId == 'usr_ali')
                            FilledButton.icon(
                              onPressed: _createGroup,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create group'),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Rows in this domain are still listed below if the '
                            'server authorises you. Membership lives in the key '
                            'wraps, not in a table the server understands.',
                            style: SyTheme.small,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Kv('group', group!.id, mono: true),
                          Kv('epoch', '${group!.epoch}', mono: true),
                          Kv('members', group!.memberIds.join(', '), mono: true),
                          const Divider(height: 22),
                          Text('Members', style: SyTheme.small),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final id in group!.memberIds)
                                InputChip(
                                  label: Text(id, style: SyTheme.mono(11.5)),
                                  backgroundColor: SyTheme.surfaceAlt,
                                  side: const BorderSide(color: SyTheme.line),
                                  onDeleted: id == s.userId ? null : () => _remove(id),
                                  deleteIcon: id == s.userId
                                      ? null
                                      : const Icon(Icons.person_remove_outlined,
                                          size: 14),
                                  deleteIconColor: SyTheme.danger,
                                ),
                              for (final p in removable)
                                if (!group!.members.containsKey(p.id))
                                  ActionChip(
                                    label: Text('+ ${p.id}', style: SyTheme.mono(11.5)),
                                    onPressed: () => _add(p.id),
                                    backgroundColor: SyTheme.surfaceAlt,
                                    side: const BorderSide(color: SyTheme.line),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (s.userId == 'usr_ali')
                            FilledButton.icon(
                              onPressed: _post,
                              icon: const Icon(Icons.lock_outline, size: 16),
                              label: Text('Post to epoch ${group!.epoch}'),
                            )
                          else
                            Text(
                              'Only the owner holds the epoch key on this device. '
                              'Members read what was wrapped for them.',
                              style: SyTheme.small,
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: Panel(
                title: 'Timeline · $domain',
                trailing: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 17)),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (rows.isEmpty)
                            EmptyState(
                              s.userId == 'usr_mona'
                                  ? 'Mona sees nothing after the rotation.\nThe rows still exist; she is not in their wraps.'
                                  : 'No group messages yet.',
                              icon: Icons.forum_outlined,
                            ),
                          for (final m in rows)
                            InkWell(
                              onTap: () => _open(m),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: openId == m.id
                                      ? SyTheme.violet.withValues(alpha: 0.10)
                                      : SyTheme.surfaceAlt,
                                  border: Border.all(
                                      color: openId == m.id
                                          ? SyTheme.violet.withValues(alpha: 0.5)
                                          : SyTheme.line),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(m.id,
                                            style: SyTheme.mono(11.5, SyTheme.text)),
                                        const Spacer(),
                                        Pill('${m.readers.length} readers',
                                            color: SyTheme.violet),
                                        const SizedBox(width: 6),
                                        Text(stamp(m.updatedAt),
                                            style: SyTheme.mono(10.5)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(m.readers.join(' · '),
                                        style: SyTheme.mono(10.5, SyTheme.muted)),
                                    if (openId == m.id) ...[
                                      const SizedBox(height: 10),
                                      if (opened != null)
                                        Container(
                                          padding: const EdgeInsets.all(11),
                                          decoration: BoxDecoration(
                                            color: SyTheme.violet.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: SelectableText(opened!,
                                              style: SyTheme.body.copyWith(fontSize: 14)),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Removal is not erasure',
          child: Text(
            'When a member is removed the epoch advances and a fresh key is '
            'generated. Everything sealed after that point is out of their reach. '
            'Everything sealed before it is still theirs to read — they had the '
            'key when it was written. An implementation that hides this is lying '
            'about what it can promise.',
            style: SyTheme.body.copyWith(color: SyTheme.muted),
          ),
        ),
      ],
    );
  }
}
