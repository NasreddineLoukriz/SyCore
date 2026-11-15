import 'package:flutter/material.dart';
import 'package:sycore_client/sycore_client.dart';
import 'package:sycore_core/sycore_core.dart' as core;

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
  String? note;
  String? localError;
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

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final f = await s.sdk.jahr.feed(project: AppState.project, domain: domain);
      if (mounted) setState(() => feed = f);
    } catch (e) {
      if (mounted) setState(() => localError = s.describe(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _publish() async {
    final text = TextEditingController(
        text: 'How to build a server that cannot read your data');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SyTheme.surface,
        title: const Text('Publish publicly'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Zero wraps. The bytes are stored in clear, and an Ed25519 '
                'signature binds them to this identity, this project, this '
                'domain and this row id.',
                style: SyTheme.small,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: text,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Content'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.public, size: 16),
            label: const Text('Sign & publish'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final env = await s.guard(() => s.sdk.jahr.publish(
          project: AppState.project,
          domain: domain,
          text: text.text,
        ));
    if (env != null) {
      setState(() => note = 'Published ${env.id} · 0 wraps · 1 signature.');
      await _load();
    }
  }

  Future<void> _verify(ResourceMeta m) async {
    final check = await s.guard(() => s.sdk.jahr.verify(m.id));
    if (check != null) setState(() => checks[m.id] = check);
  }

  /// The experiment a professor asks for: verify with the key shipped in the
  /// payload (passes) versus the directory (fails).
  Future<void> _runExperiment() async {
    final a = s.account;
    if (a == null) return;
    final attacker =
        await core.Identity.create('usr_attacker', seed: core.utf8b('attacker'));
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
    setState(() {
      experimentRun = true;
      trapResult = trap;
      defenceResult = defence;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (s.error != null) ErrorBanner(s.error!),
        if (localError != null) ErrorBanner(localError!),
        if (note != null) ...[OkBanner(note!), const SizedBox(height: 14)],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Panel(
                title: 'Public · $domain',
                trailing: FilledButton.icon(
                  onPressed: _publish,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Publish'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'JAHR is the one engine where the content is not secret — '
                      'it is public by design. What is protected is authorship.',
                      style: SyTheme.small,
                    ),
                    const SizedBox(height: 14),
                    if (loading)
                      const Center(child: CircularProgressIndicator())
                    else if (feed.isEmpty)
                      const EmptyState('Nothing published yet.')
                    else
                      for (final m in feed) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SyTheme.surfaceAlt,
                            border: Border.all(color: SyTheme.line),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(m.id,
                                        style: SyTheme.mono(11.5, SyTheme.text)),
                                  ),
                                  _CheckChip(checks[m.id]),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${m.ownerId} · ${stamp(m.updatedAt)}',
                                  style: SyTheme.mono(10.5, SyTheme.muted)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _verify(m),
                                    icon: const Icon(Icons.verified_outlined, size: 14),
                                    label: const Text('Verify'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () async {
                                      final text =
                                          await s.sdk.jahr.read(m.id);
                                      if (!context.mounted) return;
                                      showDialog<void>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: SyTheme.surface,
                                          title: Text('Read anonymously · ${m.id}'),
                                          content: SizedBox(
                                              width: 460,
                                              child: SelectableText(text,
                                                  style: SyTheme.body
                                                      .copyWith(fontSize: 14))),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text('Close')),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text('Read as anonymous'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Panel(
                title: 'The trap',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'An attacker publishes in your name and signs with his own '
                      'key — and helpfully ships that key with the payload. '
                      'Verification that reads the key from the payload says yes.',
                      style: SyTheme.small,
                    ),
                    const SizedBox(height: 12),
                    if (!experimentRun)
                      OutlinedButton.icon(
                        onPressed: _runExperiment,
                        icon: const Icon(Icons.science_outlined, size: 15),
                        label: const Text('Run the forgery experiment'),
                      )
                    else ...[
                      _Verdict(
                        label: 'key from the payload',
                        ok: trapResult == true,
                        expect: 'must be rejected',
                      ),
                      const SizedBox(height: 8),
                      _Verdict(
                        label: 'key from the directory',
                        ok: defenceResult == false,
                        expect: 'must be rejected',
                      ),
                      const SizedBox(height: 10),
                      OkBanner(
                        defenceResult == false
                            ? 'The forgery only survives against a key the attacker '
                                'supplied. The directory is what makes it fail.'
                            : 'Something is wrong: the directory accepted a forgery.',
                      ),
                    ],
                    const Divider(height: 26),
                    Text(
                      'This is why spec/SPEC.md §7 forbids taking a public key from '
                      'the payload being verified. A verifier that does is not '
                      'verifying anything.',
                      style: SyTheme.small,
                    ),
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

class _CheckChip extends StatelessWidget {
  const _CheckChip(this.check);

  final JahrCheck? check;

  @override
  Widget build(BuildContext context) {
    if (check == null) return const SizedBox.shrink();
    if (check!.verified) {
      return const Pill('verified · directory', color: SyTheme.ok, icon: Icons.verified);
    }
    return Pill(
      check!.reason == 'unknown_signer' ? 'unknown signer' : 'bad signature',
      color: SyTheme.danger,
      icon: Icons.gpp_bad_outlined,
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.label, required this.ok, required this.expect});

  final String label;

  /// True when the outcome is the one we want to see.
  final bool ok;
  final String expect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (ok ? SyTheme.ok : SyTheme.danger).withValues(alpha: 0.09),
        border: Border.all(
            color: (ok ? SyTheme.ok : SyTheme.danger).withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
              size: 16, color: ok ? SyTheme.ok : SyTheme.danger),
          const SizedBox(width: 9),
          Expanded(child: Text(label, style: SyTheme.mono(12))),
          Text(ok ? 'blocked' : 'accepted',
              style: SyTheme.mono(11.5, ok ? SyTheme.ok : SyTheme.danger)),
        ],
      ),
    );
  }
}
