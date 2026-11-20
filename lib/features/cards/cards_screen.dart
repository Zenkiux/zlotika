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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          PageHeader(context.s('cardsTitle'), subtitle: context.s('cardsSub'), trailing: const SettingsButton()),
          if (s.wallet.isEmpty)
            Panel(
              child: Row(children: [
                const IconTile(Icons.credit_card_rounded),
                const SizedBox(width: 12),
                Expanded(child: Text(context.s('cardsEmpty'), style: context.tt.bodyMedium)),
              ]),
            ),
          for (final card in s.wallet) Padding(padding: const EdgeInsets.only(bottom: 10), child: _CardTile(card)),
          const SizedBox(height: 6),
          BigButton(label: context.s('cardsAdd'), icon: Icons.add_rounded, onPressed: () => addCardFlow(context)),
          if (missing.isNotEmpty) ...[
            SectionTitle(context.s('cardsSuggested')),
            RowGroup(children: [
              for (var i = 0; i < missing.length; i++)
                _SuggestRow(type: missing[i], last: i == missing.length - 1),
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
    return Material(
      color: t.color,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCard(context, card),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: context.tt.bodySmall!.copyWith(color: t.ink.withValues(alpha: .8))),
                Text(card.title, style: context.tt.titleLarge!.copyWith(color: t.ink)),
                const SizedBox(height: 6),
                Text(_spaced(card.code), style: context.tt.bodyMedium!.copyWith(color: t.ink.withValues(alpha: .85), fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
            Icon(Icons.qr_code_2_rounded, color: t.ink, size: 30),
          ]),
        ),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: t.color,
        foregroundColor: t.ink,
        title: Text(card.title, style: context.tt.titleLarge!.copyWith(color: t.ink)),
        actions: [
          IconButton(
            tooltip: context.s('delete'),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
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
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              BarcodeWidget(
                barcode: _barcodeFor(card.format),
                data: card.code,
                width: qr ? 260 : double.infinity,
                height: qr ? 260 : 140,
                drawText: false,
                color: Colors.black,
                backgroundColor: Colors.white,
                errorBuilder: (ctx, err) => Text(ctx.s('cardsBadCode'), style: const TextStyle(color: Colors.black)),
              ),
              const SizedBox(height: 18),
              SelectableText(_spaced(card.code), style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black, letterSpacing: 1)),
              const SizedBox(height: 10),
              Text(context.s('cardsShowCashier'), style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF555555)), textAlign: TextAlign.center),
            ]),
          ),
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
