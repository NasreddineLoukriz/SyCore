import 'package:flutter/material.dart';

import 'l10n.dart';
import 'theme.dart';

/// A labelled block separated from its neighbours by a hairline.
///
/// There are no cards in this interface on purpose: everything sits on the
/// paper, and structure comes from rules and white space.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.note,
    this.first = false,
    this.bottom = 26,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final String? note;
  final bool first;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) const Divider(height: 1, color: SyTheme.lineSoft),
        Padding(
          padding: EdgeInsets.only(top: first ? 0 : 20, bottom: bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(title!, style: tx.labelMedium),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 12),
              ],
              child,
              if (note != null) ...[
                const SizedBox(height: 10),
                Text(note!, style: tx.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A label and a value. The label column is narrow so values line up.
class Field extends StatelessWidget {
  const Field(
    this.label,
    this.value, {
    super.key,
    this.mono = false,
    this.color,
    this.selectable = true,
  });

  final String label;
  final String value;
  final bool mono;
  final Color? color;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    final style = mono
        ? SyTheme.mono(12.5, color ?? SyTheme.inkSoft)
        : (tx.bodyMedium?.copyWith(color: color ?? SyTheme.ink) ??
            const TextStyle());
    final text = selectable
        ? SelectableText(value, style: style)
        : Text(value, style: style);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(label, style: tx.bodySmall),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: text),
        ],
      ),
    );
  }
}

/// A sentence the reader should notice, marked by a rule and a colour — not by
/// a filled, rounded box.
class Note extends StatelessWidget {
  const Note(this.text, {super.key, this.kind = NoteKind.info, this.title});

  final String text;
  final NoteKind kind;
  final String? title;

  Color get _color => switch (kind) {
        NoteKind.info => SyTheme.accent,
        NoteKind.ok => SyTheme.ok,
        NoteKind.warn => SyTheme.warn,
        NoteKind.danger => SyTheme.danger,
      };

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: _color, width: 2),
        ),
      ),
      padding: const EdgeInsetsDirectional.only(start: 12, top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: tx.titleSmall?.copyWith(color: _color)),
            const SizedBox(height: 3),
          ],
          Text(text, style: tx.bodyMedium?.copyWith(color: SyTheme.inkSoft)),
        ],
      ),
    );
  }
}

enum NoteKind { info, ok, warn, danger }

/// Small outlined word, for state that must be visible at a glance.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = SyTheme.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: tx.labelSmall?.copyWith(
          color: color,
          fontSize: (tx.labelSmall?.fontSize ?? 10.5) - 0.5,
        ),
      ),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key, required this.color, this.size = 5});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class StatusLine extends StatelessWidget {
  const StatusLine({
    super.key,
    required this.on,
    required this.text,
    this.color,
  });

  final bool on;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return Row(
      children: [
        Dot(color: on ? SyTheme.ok : SyTheme.danger),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: tx.bodySmall?.copyWith(
                color: on ? (color ?? SyTheme.muted) : SyTheme.danger),
          ),
        ),
      ],
    );
  }
}

/// Key material and wire format. Always left-to-right, even in Arabic: JSON is
/// not prose, and reversing it would be a lie about the bytes.
class Code extends StatelessWidget {
  const Code(this.text, {super.key, this.maxHeight = 300});

  final String text;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: SyTheme.inset,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          child: SelectableText(text, style: SyTheme.mono(12, SyTheme.inkSoft)),
        ),
      ),
    );
  }
}

/// One quiet line where a list would be empty.
class Blank extends StatelessWidget {
  const Blank(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(text,
          style: tx.bodySmall?.copyWith(color: SyTheme.faint)),
    );
  }
}

/// A list row: title, optional trailing word, optional second line.
class RowLine extends StatelessWidget {
  const RowLine({
    super.key,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.trailing,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? SyTheme.accentSoft : null,
          border: Border(
            bottom: BorderSide(color: SyTheme.lineSoft),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: child),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The title of a screen: one heading, one line of context, optional actions.
class PageHead extends StatelessWidget {
  const PageHead({
    super.key,
    required this.title,
    required this.blurb,
    this.actions,
  });

  final String title;
  final String blurb;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tx.headlineLarge),
                const SizedBox(height: 3),
                Text(blurb, style: tx.bodySmall),
              ],
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: 16),
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions!),
          ],
        ],
      ),
    );
  }
}

/// The one modal in the app: a title, a line of context, a body, two actions.
/// Returns true when the reader confirms.
Future<bool?> showSheet(
  BuildContext context, {
  required String title,
  required String note,
  required Widget body,
  required String confirmLabel,
  double width = 420,
}) {
  final s = context.s;
  final tx = Theme.of(context).textTheme;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(note, style: tx.bodySmall),
            const SizedBox(height: 18),
            body,
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(s.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

String stamp(String iso) {
  if (iso.isEmpty) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)} ${two(l.hour)}:${two(l.minute)}';
}
