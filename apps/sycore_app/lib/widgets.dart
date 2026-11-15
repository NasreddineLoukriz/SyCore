import 'package:flutter/material.dart';

import 'theme.dart';

/// A bordered surface. Every screen is built from these.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
    this.accent,
    this.scrollable = false,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;
  final Color? accent;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: SyTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ?? SyTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!,
                        style: SyTheme.h2.copyWith(color: accent ?? SyTheme.text)),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          if (scrollable)
            Expanded(child: SingleChildScrollView(child: body))
          else
            body,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = SyTheme.muted, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class Kv extends StatelessWidget {
  const Kv(this.k, this.v, {super.key, this.mono = false, this.valueColor});

  final String k;
  final String v;
  final bool mono;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(k, style: SyTheme.small),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: mono
                  ? SyTheme.mono(12.5, valueColor ?? SyTheme.text)
                  : SyTheme.body.copyWith(color: valueColor ?? SyTheme.text),
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SyTheme.danger.withValues(alpha: 0.10),
        border: Border.all(color: SyTheme.danger.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: SyTheme.danger),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(message,
                style: SyTheme.body.copyWith(color: SyTheme.danger)),
          ),
        ],
      ),
    );
  }
}

class OkBanner extends StatelessWidget {
  const OkBanner(this.message, {super.key, this.color = SyTheme.ok});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: SyTheme.body.copyWith(color: color, fontSize: 12.5))),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 26, color: SyTheme.line),
          const SizedBox(height: 10),
          Text(text, style: SyTheme.small, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class MonoBlock extends StatelessWidget {
  const MonoBlock(this.text, {super.key, this.maxHeight = 260});

  final String text;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SyTheme.bg,
        border: Border.all(color: SyTheme.line),
        borderRadius: BorderRadius.circular(9),
      ),
      child: SingleChildScrollView(
        child: SelectableText(text, style: SyTheme.mono()),
      ),
    );
  }
}

String stamp(String iso) {
  if (iso.isEmpty) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)} ${two(l.hour)}:${two(l.minute)}';
}
