import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Colour role for icons, pills and stats.
enum Tone { neutral, accent, good, bad, warn, blue }

extension ToneColors on Tone {
  (Color fg, Color bg) colors(Palette c) => switch (this) {
        Tone.neutral => (c.text2, c.raised),
        Tone.accent => (c.accentText, c.accentSoft),
        Tone.good => (c.good, c.goodSoft),
        Tone.bad => (c.bad, c.badSoft),
        Tone.warn => (c.warn, c.warnSoft),
        Tone.blue => (c.blue, c.blueSoft),
      };
}

/// The logo's flag ribbon: yellow · green · red, then white · red. Used sparingly.
class FlagRibbon extends StatelessWidget {
  const FlagRibbon({super.key, this.width = 56, this.height = 4});
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final white = Theme.of(context).brightness == Brightness.dark ? Brand.white : const Color(0xFFD9DAE0);
    Widget seg(Color c) => Expanded(child: ColoredBox(color: c));
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        width: width,
        height: height,
        child: Row(children: [seg(Brand.yellow), seg(Brand.green), seg(Brand.ltRed), const SizedBox(width: 3), seg(white), seg(Brand.plRed)]),
      ),
    );
  }
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .26),
        child: Image.asset('assets/brand/app_icon_1024.png', width: size, height: size, filterQuality: FilterQuality.medium),
      );
}

/// Pressable wrapper: a light scale on press, like the prototype's :active.
class Press extends StatefulWidget {
  const Press({super.key, required this.child, this.onTap, this.scale = .985});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 110), child: widget.child),
    );
  }
}

/// Surface card with a hairline border. Tappable when [onTap] is given.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.color, this.radius = 18, this.border});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final double radius;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border != null ? BorderSide(color: border!, width: 1.5) : BorderSide(color: color == null ? c.line : Colors.transparent),
    );
    return Material(
      color: color ?? c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum BtnKind { primary, secondary, ghost, danger }

/// Full-width button, 52 px, Manrope bold.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, this.icon, this.onPressed, this.kind = BtnKind.primary, this.expand = true});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, side) = switch (kind) {
      BtnKind.primary => (c.accent, c.onAccent, null),
      BtnKind.secondary => (c.raised, c.text, c.line),
      BtnKind.ghost => (Colors.transparent, c.text2, c.line),
      BtnKind.danger => (c.badSoft, c.bad, c.bad.withValues(alpha: .25)),
    };
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: 9)],
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, textAlign: TextAlign.center, style: context.tt.labelLarge!.copyWith(color: fg)))),
      ],
    );
    return Semantics(
      button: true,
      child: Opacity(
        opacity: onPressed == null ? .45 : 1,
        child: Press(
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: side == null ? null : Border.all(color: side),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Rounded icon tile, 36 px by default, tinted by [tone].
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color, this.bg, this.size = 36, this.tone});
  final IconData icon;
  final Color? color, bg;
  final double size;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (fg, tbg) = (tone ?? Tone.neutral).colors(c);
    final neutral = tone == null || tone == Tone.neutral;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? (neutral ? c.raised : tbg),
        borderRadius: BorderRadius.circular(size * .28),
        border: bg == null && (neutral || tone == Tone.accent) ? Border.all(color: tone == Tone.accent ? c.accentLine : c.line) : null,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * .5, color: color ?? (neutral ? c.text : fg)),
    );
  }
}

/// Small uppercase section label, with an optional action on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.action, this.onAction, this.top = 22});
  final String text;
  final Widget? trailing;
  final String? action;
  final VoidCallback? onAction;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(4, top, 4, 10),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: context.tt.labelSmall!.copyWith(color: context.c.text3, letterSpacing: .66, fontSize: 12)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: context.tt.labelMedium!.copyWith(color: context.c.accentText)),
            ),
          ?trailing,
        ]),
      );
}

/// Small rounded label. Polish names use [PlName].
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.fg, this.bg, this.icon, this.tone});
  final String text;
  final Color? fg, bg;
  final IconData? icon;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (tfg, tbg) = (tone ?? Tone.neutral).colors(c);
    final f = fg ?? tfg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? tbg,
        borderRadius: BorderRadius.circular(999),
        border: (tone ?? Tone.neutral) == Tone.neutral && bg == null ? Border.all(color: c.line) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: f), const SizedBox(width: 5)],
        Flexible(child: Text(text, style: context.tt.labelSmall!.copyWith(color: f))),
      ]),
    );
  }
}

/// The red "PL" tag on its own.
class PlTag extends StatelessWidget {
  const PlTag({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 6 : 5, vertical: 1.5),
        decoration: BoxDecoration(color: Brand.plRed, borderRadius: BorderRadius.circular(5)),
        child: Text('PL', style: TextStyle(fontFamily: body, fontSize: large ? 11 : 9.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2, letterSpacing: .4)),
      );
}

/// "PL  Filet z piersi kurczaka" — the original shelf name next to a translation.
class PlName extends StatelessWidget {
  const PlName(this.name, {super.key, this.large = false, this.maxLines = 2});
  final String name;
  final bool large;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1.5), child: PlTag(large: large)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(name,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: (large ? context.tt.bodyLarge : context.tt.bodyMedium)!.copyWith(color: context.c.text2, fontSize: large ? 15 : 12.5)),
          ),
        ]),
      );
}

/// Compact stepper: two square buttons around the value.
class Stepper2 extends StatelessWidget {
  const Stepper2({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 99, this.step = 1, this.format});
  final double value, min, max, step;
  final ValueChanged<double> onChanged;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget b(IconData i, double v, bool enabled) => Press(
          onTap: enabled ? () => onChanged(double.parse(v.toStringAsFixed(2))) : null,
          scale: .92,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(9)),
            child: Icon(i, size: 19, color: enabled ? c.text : c.text3),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        b(Icons.remove_rounded, value - step, value - step >= min - 1e-9),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 52),
          child: Text(format?.call(value) ?? value.toStringAsFixed(0),
              textAlign: TextAlign.center, style: context.tt.titleMedium!.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        b(Icons.add_rounded, value + step, value + step <= max + 1e-9),
      ]),
    );
  }
}

/// A full-width choice row: accent border and tint when selected.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({super.key, required this.title, this.subtitle, required this.selected, required this.onTap, this.leading});
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Press(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? c.accent : c.line, width: 1.5),
          ),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.tt.titleMedium!.copyWith(fontSize: 15.5)),
                if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: context.tt.bodyMedium!.copyWith(fontSize: 13))),
              ]),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? c.accent : Colors.transparent,
                border: Border.all(color: selected ? c.accent : c.lineStrong, width: 2),
              ),
              child: selected ? Icon(Icons.check_rounded, size: 15, color: c.onAccent) : null,
            ),
          ]),
        ),
      ),
    );
  }
}

Future<T?> showSheet<T>(BuildContext context, Widget Function(BuildContext) builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Stack(children: [
          builder(ctx),
          // A visible way out, not only the swipe-down handle.
          Positioned(
            top: 0,
            right: 10,
            child: IconButton(
              tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
              onPressed: () => Navigator.pop(ctx),
              icon: Icon(Icons.close_rounded, size: 22, color: ctx.c.text3),
            ),
          ),
        ]),
      ),
    );

/// Segmented control: quiet track, the chosen option lifts onto a surface.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)),
      child: Row(children: [
        for (final (v, label) in options)
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                constraints: const BoxConstraints(minHeight: 36),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: v == value ? (Theme.of(context).brightness == Brightness.dark ? c.raised2 : c.surface) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: v == value ? const [BoxShadow(color: Color(0x2E000000), blurRadius: 4, offset: Offset(0, 1))] : null,
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: context.tt.labelMedium!.copyWith(fontSize: 13, color: v == value ? c.text : c.text2)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Every tab starts the same way: title, one line on what the page is for,
/// and the settings gear in the same corner.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing, this.eyebrow});
  final String title;
  final String? subtitle, eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (eyebrow != null) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(eyebrow!, style: context.tt.labelMedium!.copyWith(color: context.c.text3))),
              Text(title, style: context.tt.headlineMedium),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: context.tt.bodyMedium)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      );
}

/// Round 40 px icon button with a hairline border, for header actions.
class RoundIcon extends StatelessWidget {
  const RoundIcon(this.icon, {super.key, required this.onTap, this.tooltip, this.filled = false, this.size = 40});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final btn = Press(
      onTap: onTap,
      scale: .93,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? c.accent : c.surface,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: c.line),
        ),
        child: Icon(icon, size: size * .5, color: filled ? c.onAccent : c.text),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// A grouped list row: icon, title, subtitle, value, chevron. Rows inside a [RowGroup]
/// get an inset hairline between them.
class RowTile extends StatelessWidget {
  const RowTile({super.key, this.icon, required this.title, this.subtitle, this.value, this.onTap, this.iconColor, this.tone, this.last = false, this.trailing, this.subtitleColor, this.titleColor});
  final IconData? icon;
  final String title;
  final String? subtitle, value;
  final VoidCallback? onTap;
  final Color? iconColor, subtitleColor, titleColor;
  final Tone? tone;
  final bool last;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
          child: Row(children: [
            if (icon != null) ...[IconTile(icon!, tone: tone, color: iconColor), const SizedBox(width: 13)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.tt.titleMedium!.copyWith(color: titleColor)),
                if (subtitle != null)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: context.tt.bodyMedium!.copyWith(fontSize: 13, color: subtitleColor))),
              ]),
            ),
            if (value != null) ...[const SizedBox(width: 8), Text(value!, style: context.tt.titleMedium!.copyWith(color: c.text2, fontSize: 14))],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null && trailing == null) ...[const SizedBox(width: 6), Icon(Icons.chevron_right_rounded, size: 20, color: c.text3)],
          ]),
        ),
      ),
    );
  }
}

/// Rows in one bordered group, like iOS settings.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Panel(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
}

/// Small number card: label, big value, note.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.sub, this.valueColor, this.subColor});
  final String label, value;
  final String? sub;
  final Color? valueColor, subColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall!.copyWith(color: c.text2, fontSize: 11.5)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: context.tt.headlineSmall!.copyWith(color: valueColor, fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        if (sub != null)
          Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, maxLines: 2, style: context.tt.bodySmall!.copyWith(fontSize: 11.5, color: subColor))),
      ]),
    );
  }
}

/// Red (or other tone) banner with an icon, a bold title and a line of body text.
class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key, required this.title, this.body, this.tone = Tone.bad, this.icon = Icons.warning_amber_rounded});
  final String title;
  final String? body;
  final Tone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (fg, bg) = tone.colors(c);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: fg.withValues(alpha: .28))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: fg),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.tt.titleMedium!.copyWith(color: fg, fontSize: 13.5, fontWeight: FontWeight.w700)),
            if (body != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(body!, style: context.tt.bodyMedium!.copyWith(color: c.text, fontSize: 12.5))),
          ]),
        ),
      ]),
    );
  }
}

/// Pill-shaped filter chip; active = accent tint.
class FilterChip2 extends StatelessWidget {
  const FilterChip2({super.key, required this.label, required this.active, required this.onTap, this.dot, this.icon});
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Press(
        onTap: onTap,
        scale: .95,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? c.accentSoft : c.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? c.accentLine : c.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot != null) ...[Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 6)],
            if (icon != null) ...[Icon(icon, size: 15, color: active ? c.accentText : c.text2), const SizedBox(width: 6)],
            Text(label, style: context.tt.labelMedium!.copyWith(color: active ? c.accentText : c.text2)),
          ]),
        ),
      ),
    );
  }
}

/// Coloured dot for a chain.
class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 9});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Two side-by-side children of equal width.
class Pair extends StatelessWidget {
  const Pair(this.a, this.b, {super.key, this.gap = 10});
  final Widget a, b;
  final double gap;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: a), SizedBox(width: gap), Expanded(child: b)]),
      );
}
