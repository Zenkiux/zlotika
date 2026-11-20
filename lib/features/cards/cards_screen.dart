import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide Barcode;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../services/wallet.dart';
import '../../widgets/ui.dart';
import '../more/more_screen.dart';

/// Loyalty cards in one place. Tap a card at the till: big barcode, bright screen.
class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final missing = cardTypes.where((t) => t.id != 'other' && !s.wallet.any((c) => c.type == t.id)).toList();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          PageHeader(context.s('cardsTitle'), subtitle: context.s('cardsSub'), trailing: const SettingsButton()),
          if (s.wallet.isEmpty)
            Panel(
              child: Row(children: [
                const IconTile(Icons.credit_card_rounded, tone: Tone.accent),
                const SizedBox(width: 12),
                Expanded(child: Text(context.s('cardsEmpty'), style: context.tt.bodyMedium)),
              ]),
            ),
          for (final card in s.wallet) Padding(padding: const EdgeInsets.only(bottom: 12), child: _CardTile(card)),
          const SizedBox(height: 8),
          BigButton(label: context.s('cardsAdd'), icon: Icons.add_rounded, onPressed: () => addCardFlow(context)),
          if (missing.isNotEmpty) ...[
            SectionTitle(context.s('cardsSuggested')),
            RowGroup(children: [
              for (var i = 0; i < missing.length; i++) _SuggestRow(type: missing[i], last: i == missing.length - 1),
            ]),
          ],
          const SizedBox(height: 14),
          Text(context.s('cardsPrivacy'), style: context.tt.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SuggestRow extends StatelessWidget {
  const _SuggestRow({required this.type, required this.last});
  final CardType type;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => type.dynamicCode ? _dynamicInfo(context, type) : addCardFlow(context, type: type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: context.c.line))),
        child: Row(children: [
          CardChip(type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type.program, style: context.tt.titleMedium),
              Text(context.s(type.dynamicCode ? 'cardsAppOnly' : 'cardsScanOrType'), style: context.tt.bodySmall),
            ]),
          ),
          Icon(type.dynamicCode ? Icons.open_in_new_rounded : Icons.add_circle_outline_rounded, color: context.c.text3),
        ]),
      ),
    );
  }
}

/// Small square in the card's brand colour with its initial.
class CardChip extends StatelessWidget {
  const CardChip(this.type, {super.key, this.size = 36});
  final CardType type;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: type.color, borderRadius: BorderRadius.circular(size * .28)),
        child: Text(type.name.characters.first, style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: size * .45, color: type.ink)),
      );
}

class _CardTile extends StatelessWidget {
  const _CardTile(this.card);
  final LoyaltyCard card;

  @override
  Widget build(BuildContext context) {
    final t = card.t;
    const white = Colors.white;
    return Press(
      onTap: () => showCard(context, card),
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.gradient),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x1FFFFFFF)),
          boxShadow: const [BoxShadow(color: Color(0x38000000), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Stack(children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(width: 110, height: 110, decoration: const BoxDecoration(color: Color(0x1AFFFFFF), shape: BoxShape.circle)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(card.title, style: context.tt.titleLarge!.copyWith(color: white, fontSize: 18))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0x38000000), borderRadius: BorderRadius.circular(999)),
                  child: Text(t.dynamicCode ? context.s('cardsRotating') : card.format.name.toUpperCase(),
                      style: context.tt.labelSmall!.copyWith(color: const Color(0xEBFFFFFF), fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Text(_spaced(card.code),
                      style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, letterSpacing: 1, color: Color(0xE0FFFFFF), fontFeatures: [FontFeature.tabularFigures()])),
                ),
                Text('${context.s('cardsShowHint')} →', style: context.tt.labelMedium!.copyWith(color: const Color(0xE6FFFFFF), fontSize: 12)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

String _spaced(String code) => RegExp(r'^\d+$').hasMatch(code) ? code.replaceAllMapped(RegExp(r'.{1,4}'), (m) => '${m[0]} ').trim() : code;

Barcode _barcodeFor(CodeFormat f) => switch (f) {
      CodeFormat.ean13 => Barcode.ean13(),
      CodeFormat.ean8 => Barcode.ean8(),
      CodeFormat.code128 => Barcode.code128(),
      CodeFormat.qr => Barcode.qrCode(),
    };

/// Full-screen card for the cashier: white background, large code, maximum brightness.
Future<void> showCard(BuildContext context, LoyaltyCard card) =>
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _CardView(card)));

class _CardView extends StatefulWidget {
  const _CardView(this.card);
  final LoyaltyCard card;

  @override
  State<_CardView> createState() => _CardViewState();
}

class _CardViewState extends State<_CardView> {
  @override
  void initState() {
    super.initState();
    ScreenBrightness.instance.setApplicationScreenBrightness(1.0).catchError((_) {});
  }

  @override
  void dispose() {
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final t = card.t;
    final qr = card.format == CodeFormat.qr;
    Future<void> remove() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.s('cardsDeleteQ'), style: ctx.tt.headlineSmall),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.s('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.s('delete'), style: TextStyle(color: ctx.c.bad))),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        AppScope.read(context).removeCard(card.id);
        Navigator.pop(context);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x29F5C43D), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wb_sunny_outlined, size: 14, color: Brand.yellow),
                  const SizedBox(width: 6),
                  Text(context.s('cardsBright'), style: context.tt.labelMedium!.copyWith(color: Brand.yellow, fontSize: 12)),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Color(0x1FFFFFFF), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 26),
            Text(card.title, textAlign: TextAlign.center, style: context.tt.headlineSmall!.copyWith(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 4),
            Text(context.s('cardsShowCashier'), textAlign: TextAlign.center, style: context.tt.bodyMedium!.copyWith(color: const Color(0xFF94A3B8))),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 50, offset: Offset(0, 20))],
              ),
              child: Column(children: [
                BarcodeWidget(
                  barcode: _barcodeFor(card.format),
                  data: card.code,
                  width: qr ? 240 : double.infinity,
                  height: qr ? 240 : 130,
                  drawText: false,
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  errorBuilder: (ctx, err) => Text(ctx.s('cardsBadCode'), style: const TextStyle(color: Colors.black)),
                ),
                const SizedBox(height: 14),
                SelectableText(_spaced(card.code),
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0B0C0F), letterSpacing: 2.4)),
              ]),
            ),
            const Spacer(),
            Text(t.program, textAlign: TextAlign.center, style: context.tt.bodySmall!.copyWith(color: const Color(0xFF687082))),
            const SizedBox(height: 12),
            BigButton(label: context.s('cardsRemove'), kind: BtnKind.danger, onPressed: remove),
          ]),
        ),
      ),
    );
  }
}

void _dynamicInfo(BuildContext context, CardType t) => showSheet(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [CardChip(t, size: 44), const SizedBox(width: 12), Expanded(child: Text(t.program, style: ctx.tt.headlineSmall))]),
          const SizedBox(height: 12),
          Text(ctx.s('cardsDynamic', {'app': t.program}), style: ctx.tt.bodyLarge),
          const SizedBox(height: 18),
          BigButton(
            label: ctx.s('cardsOpenApp', {'app': t.program}),
            icon: Icons.open_in_new_rounded,
            onPressed: () => launchUrl(Uri.parse(t.appUrl!), mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 8),
          BigButton(
            label: ctx.s('cardsAddAnyway'),
            kind: BtnKind.ghost,
            onPressed: () {
              Navigator.pop(ctx);
              addCardFlow(context, type: t);
            },
          ),
        ]),
      ),
    );

/// Pick the shop (unless given), then scan the card or type its number.
Future<void> addCardFlow(BuildContext context, {CardType? type}) async {
  final t = type ??
      await showSheet<CardType>(
        context,
        (ctx) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(ctx.s('cardsWhich'), style: ctx.tt.headlineSmall),
            const SizedBox(height: 14),
            for (final ct in cardTypes)
              ChoiceRow(
                title: ct.id == 'other' ? ctx.s('cardsOther') : ct.program,
                subtitle: ct.dynamicCode ? ctx.s('cardsAppOnly') : null,
                selected: false,
                leading: CardChip(ct),
                onTap: () => Navigator.pop(ctx, ct),
              ),
          ],
        ),
      );
  if (t == null || !context.mounted) return;
  if (t.dynamicCode && type == null) return _dynamicInfo(context, t);
  await showSheet(context, (ctx) => _AddCardSheet(type: t));
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet({required this.type});
  final CardType type;

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _code = TextEditingController();
  final _label = TextEditingController();
  CodeFormat? _scanned;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final r = await Navigator.of(context).push<(String, CodeFormat)>(MaterialPageRoute(builder: (_) => const _CardScanner()));
    if (r == null) return;
    setState(() {
      _code.text = r.$1;
      _scanned = r.$2;
      _error = null;
    });
  }

  void _save() {
    final code = _code.text.trim().replaceAll(' ', '');
    if (code.length < 4) {
      setState(() => _error = context.s('cardsNeedCode'));
      return;
    }
    final fmt = _scanned ?? LoyaltyCard.guess(code);
    final card = LoyaltyCard(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: widget.type.id,
      code: code,
      format: fmt,
      label: widget.type.id == 'other' ? _label.text.trim() : null,
    );
    AppScope.read(context).addCard(card);
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.type;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CardChip(t, size: 44),
          const SizedBox(width: 12),
          Expanded(child: Text(t.id == 'other' ? context.s('cardsOther') : t.program, style: context.tt.headlineSmall)),
        ]),
        const SizedBox(height: 18),
        BigButton(label: context.s('cardsScan'), icon: Icons.qr_code_scanner_rounded, onPressed: _scan),
        const SizedBox(height: 16),
        Text(context.s('cardsOrType'), style: context.tt.labelMedium),
        const SizedBox(height: 8),
        if (t.id == 'other') ...[
          TextField(controller: _label, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: context.s('cardsNameHint'))),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _code,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          onChanged: (_) => setState(() {
            _scanned = null;
            _error = null;
          }),
          decoration: InputDecoration(hintText: context.s('cardsNumberHint'), errorText: _error),
        ),
        const SizedBox(height: 18),
        BigButton(label: context.s('save'), icon: Icons.check_rounded, kind: BtnKind.secondary, onPressed: _save),
      ]),
    );
  }
}

class _CardScanner extends StatefulWidget {
  const _CardScanner();

  @override
  State<_CardScanner> createState() => _CardScannerState();
}

class _CardScannerState extends State<_CardScanner> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CodeFormat _fmt(BarcodeFormat f) => switch (f) {
        BarcodeFormat.ean13 => CodeFormat.ean13,
        BarcodeFormat.ean8 => CodeFormat.ean8,
        BarcodeFormat.qrCode => CodeFormat.qr,
        _ => CodeFormat.code128,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(context.s('cardsScan'), style: context.tt.titleLarge!.copyWith(color: Colors.white))),
        body: Stack(fit: StackFit.expand, children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v == null || v.isEmpty) continue;
                _done = true;
                HapticFeedback.mediumImpact();
                Navigator.pop(context, (v, _fmt(b.format)));
                return;
              }
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.s('scanNoCamera'), textAlign: TextAlign.center, style: context.tt.titleMedium!.copyWith(color: Colors.white)),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 300,
                height: 190,
                decoration: BoxDecoration(border: Border.all(color: Brand.yellow, width: 2.5), borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(context.s('cardsScanHint'), textAlign: TextAlign.center, style: context.tt.titleMedium!.copyWith(color: Colors.white)),
          ),
        ]),
      );
}
