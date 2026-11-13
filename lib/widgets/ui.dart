import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// The logo's flag ribbon: yellow · green · red, then white · red. Used sparingly.
class FlagRibbon extends StatelessWidget {
  const FlagRibbon({super.key, this.width = 56, this.height = 4});
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final white = context.c.text == Brand.white ? Brand.white : const Color(0xFFD9DAE0);
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

/// Surface card. Tappable when [onTap] is given.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(20), this.color, this.radius = 24, this.border});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final double radius;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border == null ? BorderSide.none : BorderSide(color: border!, width: 1.5),
    );
    return Material(
      color: color ?? context.c.surface,
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

/// Large, clearly labelled button (min 58 px tall).
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
    final (bg, fg) = switch (kind) {
      BtnKind.primary => (Brand.yellow, Brand.ink),
      BtnKind.secondary => (c.raised, c.text),
      BtnKind.ghost => (Colors.transparent, c.text),
      BtnKind.danger => (c.badSoft, c.bad),
    };
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 22, color: fg), const SizedBox(width: 10)],
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, textAlign: TextAlign.center, style: context.tt.labelLarge!.copyWith(color: fg)))),
      ],
    );
    return Semantics(
      button: true,
      child: Material(
        color: onPressed == null ? bg.withValues(alpha: .4) : bg,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), child: child),
          ),
        ),
      ),
    );
  }
}

/// Round icon in a soft tile, used as a visual anchor for rows and actions.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color, this.bg, this.size = 48});
  final IconData icon;
  final Color? color, bg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg ?? context.c.raised, borderRadius: BorderRadius.circular(size * .32)),
        alignment: Alignment.center,
        child: Icon(icon, size: size * .5, color: color ?? context.c.text),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
        child: Row(children: [Expanded(child: Text(text, style: context.tt.titleLarge)), ?trailing]),
      );
}

/// Small rounded label. Polish names use [PlTag].
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.fg, required this.bg, this.icon});
  final String text;
  final Color fg, bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 5)],
          Flexible(child: Text(text, style: context.tt.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w700))),
        ]),
      );
}

/// "PL  Filet z piersi kurczaka" — the original shelf name next to a translation.
class PlName extends StatelessWidget {
  const PlName(this.name, {super.key, this.large = false});
  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: Brand.plRed, borderRadius: BorderRadius.circular(5)),
            child: Text('PL', style: TextStyle(fontFamily: 'Inter', fontSize: large ? 12 : 10.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (large ? context.tt.titleMedium : context.tt.bodyMedium)!.copyWith(fontStyle: FontStyle.italic, color: context.c.text2)),
          ),
        ],
      );
}

/// Stepper with large hit targets for quantities and numbers.
class Stepper2 extends StatelessWidget {
  const Stepper2({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 99, this.step = 1, this.format});
  final double value, min, max, step;
  final ValueChanged<double> onChanged;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, double v, bool enabled) => SizedBox(
          width: 52,
          height: 52,
          child: IconButton(
            onPressed: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onChanged(double.parse(v.toStringAsFixed(2)));
                  }
                : null,
            icon: Icon(i, size: 24),
          ),
        );
    return Container(
      decoration: BoxDecoration(color: context.c.raised, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        b(Icons.remove_rounded, value - step, value - step >= min - 1e-9),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56),
          child: Text(format?.call(value) ?? value.toStringAsFixed(0), textAlign: TextAlign.center, style: context.tt.titleLarge),
        ),
        b(Icons.add_rounded, value + step, value + step <= max + 1e-9),
      ]),
    );
  }
}

/// A full-width choice row with a check mark — easier than radio buttons.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({super.key, required this.title, this.subtitle, required this.selected, required this.onTap, this.leading});
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: selected ? Brand.yellow : null,
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.tt.titleMedium),
                if (subtitle != null) Text(subtitle!, style: context.tt.bodyMedium),
              ]),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: selected
                  ? const Icon(Icons.check_circle_rounded, key: ValueKey(1), color: Brand.yellow, size: 28)
                  : Icon(Icons.circle_outlined, key: const ValueKey(0), color: context.c.line, size: 28),
            ),
          ]),
        ),
      );
}

Future<T?> showSheet<T>(BuildContext context, Widget Function(BuildContext) builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: builder(ctx),
      ),
    );
