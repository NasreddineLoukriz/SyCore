import 'package:flutter/material.dart';
import 'package:sycore_client/sycore_client.dart';
import 'package:sycore_core/sycore_core.dart' as core;

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class JahrScreen extends StatefulWidget {
  const JahrScreen({super.key, required this.state});

  final AppState state;

  @override
  State<JahrScreen> createState() => _JahrScreenState();
}

class _JahrScreenState extends State<JahrScreen> {
  static const domain = 'blog';

  List<ResourceMeta> feed = const [];
  final Map<String, JahrCheck> checks = {};
  String? noteKey;
  Map<String, Object?> noteVars = const {};
  String? _errKey;
  Map<String, Object?> _errVars = const {};
  bool loading = true;
  bool experimentRun = false;
  bool? trapResult;
  bool? defenceResult;

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
      final f = await s.sdk.jahr.feed(project: AppState.project, domain: domain);
      if (mounted) setState(() => feed = f);
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _publish() async {
    final t = context.s;
    final text = TextEditingController(
        text: 'How to build a server that cannot read your data');
    final ok = await showSheet(
      context,
      title: t.t('publish_title'),
      note: t.t('publish_dialog_note'),
      confirmLabel: t.t('sign_publish'),
      width: 480,
      body: TextField(
        controller: text,
        maxLines: 5,
        decoration: InputDecoration(labelText: t.t('content')),
      ),
    );
    if (ok != true) return;
    final env = await s.guard(() => s.sdk.jahr.publish(
          project: AppState.project,
          domain: domain,
          text: text.text,
        ));
    if (env != null) {
      setState(() {
        noteKey = 'published';
        noteVars = {'id': env.id};
      });
      await _load();
    }
  }

  Future<void> _verify(ResourceMeta m) async {
    final check = await s.guard(() => s.sdk.jahr.verify(m.id));
    if (check != null) setState(() => checks[m.id] = check);
  }

  Future<void> _read(ResourceMeta m) async {
    final t = context.s;
    final text = await s.guard(() => s.sdk.jahr.read(m.id));
    if (text == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('read_anonymous_title', {'id': m.id})),
        content: SizedBox(
          width: 460,
          child: SelectableText(text,
              style: Theme.of(ctx).textTheme.bodyLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.t('close')),
          ),
        ],
      ),
    );
  }

  /// The experiment a professor asks for: verify with the key shipped in the
  /// payload (passes) versus the directory (fails).
  Future<void> _runExperiment() async {
    final a = s.account;
    if (a == null) return;
    final attacker = await core.Identity.create('usr_attacker',
        seed: core.utf8b('attacker'));
    final fake = await core.publishPublic(
      projectId: AppState.project,
      domain: domain,
      resourceId: 'res_forged',
      ownerId: a.userId,
      owner: attacker,
      content: core.utf8b('I am ${a.userId}, send your keys to me'),
    );
    final content = core.unb64u(fake.ciphertext);
    final trap = await core.verifyWithPayloadKey(
      envelope: fake,
      content: content,
      attackerPublicKey: await attacker.signingPublic(),
    );
    final dir = core.IdentityDirectory()
      ..registerPublic(a.userId, await a.identity.dhPublic(),
          await a.identity.signingPublic());
    final defence = await core.verifyPublic(
        envelope: fake, content: content, directory: dir);
    if (!mounted) return;
    setState(() {
      experimentRun = true;
      trapResult = trap;
      defenceResult = defence;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tx = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 48),
      children: [
        PageHead(
          title: '${t.t('nav_public')} · $domain',
          blurb: t.t('nav_blurb_public'),
          actions: [
            OutlinedButton(
              onPressed: _publish,
              child: Text(t.t('publish')),
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
            // ── the feed ────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Section(
                first: true,
                title: '${t.t('public')} · $domain',
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  tooltip: t.t('refresh'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.t('publish_note'), style: tx.bodySmall),
                    const SizedBox(height: 14),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: LinearProgressIndicator(),
                      )
                    else if (feed.isEmpty)
                      Blank(t.t('nothing_published'))
                    else
                      for (final m in feed)
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: SyTheme.lineSoft)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 13, horizontal: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(m.id,
                                        style: SyTheme.mono(11.5, SyTheme.ink)),
                                  ),
                                  if (checks[m.id] != null) ...[
                                    _CheckTag(checks[m.id]!, t),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(stamp(m.updatedAt),
                                      style: tx.labelSmall),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  '${m.ownerId} · '
                                  '${t.t('chars', {'n': m.ciphertextChars})}',
                                  style: tx.labelSmall),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => _verify(m),
                                    child: Text(t.t('verify')),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton(
                                    onPressed: () => _read(m),
                                    child: Text(t.t('read_anonymous')),
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
            const SizedBox(width: 56),
            // ── the trap ────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Section(
                first: true,
                title: t.t('trap'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.t('trap_note'), style: tx.bodySmall),
                    const SizedBox(height: 16),
                    if (!experimentRun)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton(
                          onPressed: _runExperiment,
                          child: Text(t.t('run_experiment')),
                        ),
                      )
                    else ...[
                      _Verdict(
                        label: t.t('key_from_payload'),
                        accepted: trapResult == true,
                        acceptWord: t.t('accepted'),
                        blockWord: t.t('blocked'),
                      ),
                      const SizedBox(height: 6),
                      _Verdict(
                        label: t.t('key_from_directory'),
                        accepted: defenceResult != false,
                        acceptWord: t.t('accepted'),
                        blockWord: t.t('blocked'),
                      ),
                      const SizedBox(height: 16),
                      Note(
                        defenceResult == false
                            ? t.t('trap_conclusion')
                            : t.t('trap_broken'),
                        kind: defenceResult == false
                            ? NoteKind.ok
                            : NoteKind.danger,
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(t.t('trap_footnote'), style: tx.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckTag extends StatelessWidget {
  const _CheckTag(this.check, this.t);

  final JahrCheck check;
  final Strings t;

  @override
  Widget build(BuildContext context) {
    if (check.verified) {
      return Tag(t.t('verified_directory'), color: SyTheme.ok);
    }
    return Tag(
      check.reason == 'unknown_signer'
          ? t.t('unknown_signer')
          : t.t('bad_signature'),
      color: SyTheme.danger,
    );
  }
}

/// For a verifier, accepting is always the unsafe outcome: green means the
/// claim was rejected.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.label,
    required this.accepted,
    required this.acceptWord,
    required this.blockWord,
  });

  final String label;
  final bool accepted;
  final String acceptWord;
  final String blockWord;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    final color = accepted ? SyTheme.danger : SyTheme.ok;
    return Row(
      children: [
        Expanded(child: Text(label, style: tx.bodyMedium)),
        Text(accepted ? acceptWord : blockWord,
            style: tx.titleSmall?.copyWith(color: color)),
      ],
    );
  }
}
