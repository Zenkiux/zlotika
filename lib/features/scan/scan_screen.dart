import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_state.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../services/off.dart';
import '../../widgets/ui.dart';
import '../list/add_item_screen.dart' show newId;

/// Barcode → product name via Open Food Facts, then add to the list.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handle(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    await _controller.stop();
    final (result, product) = await OffService.lookup(code);
    if (!mounted) return;
    await showSheet(context, (_) => _ResultSheet(code: code, result: result, product: product));
    if (!mounted) return;
    setState(() => _busy = false);
    await _controller.start();
  }

  Future<void> _manual() async {
    final ctl = TextEditingController();
    final code = await showSheet<String>(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.s('scanManual'), style: ctx.tt.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            controller: ctl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
            style: ctx.tt.headlineSmall!.copyWith(letterSpacing: 2),
            decoration: const InputDecoration(hintText: '5900000000000'),
          ),
          const SizedBox(height: 16),
          BigButton(label: ctx.s('scanFind'), icon: Icons.search_rounded, onPressed: () => Navigator.pop(ctx, ctl.text)),
        ]),
      ),
    );
    if (code != null && code.length >= 8) _handle(code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(context.s('scanTitle'), style: context.tt.titleLarge!.copyWith(color: Colors.white)),
        ),
        body: Stack(fit: StackFit.expand, children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final v = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstWhere((x) => RegExp(r'^\d{8,14}$').hasMatch(x), orElse: () => '');
              if (v.isNotEmpty) _handle(v);
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
                width: 280,
                height: 170,
                decoration: BoxDecoration(border: Border.all(color: Brand.yellow, width: 3), borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
          if (_busy) const Center(child: CircularProgressIndicator(color: Brand.yellow)),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_busy ? context.s('scanLooking') : context.s('scanHint'),
                    textAlign: TextAlign.center, style: context.tt.titleMedium!.copyWith(color: Colors.white)),
                const SizedBox(height: 16),
                BigButton(label: context.s('scanManual'), icon: Icons.keyboard_rounded, kind: BtnKind.secondary, onPressed: _manual),
              ]),
            ),
          ),
        ]),
      );
}

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({required this.code, required this.result, required this.product});
  final String code;
  final OffResult result;
  final OffProduct? product;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late final _name = TextEditingController(text: widget.product?.name ?? widget.product?.plName ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final p = widget.product;
    AppScope.read(context).addItem(ListItem(id: newId(), name: name, plName: p?.plName ?? (p?.name != name ? p?.name : null), barcode: widget.code));
    final messenger = ScaffoldMessenger.of(context);
    final msg = context.s('addAdded', {'name': name});
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.result == OffResult.found && p != null) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(p.imageUrl!, width: 84, height: 84, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 84, height: 84)),
              ),
            if (p.imageUrl != null) const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name ?? p.plName ?? widget.code, style: context.tt.headlineSmall),
                if (p.plName != null && p.plName != p.name) ...[const SizedBox(height: 6), PlName(p.plName!)],
                const SizedBox(height: 6),
                Text([p.brand, p.quantity].whereType<String>().join(' · '), style: context.tt.bodyMedium),
              ]),
            ),
          ]),
        ] else ...[
          Text(widget.result == OffResult.offline ? context.s('scanOffline') : context.s('scanUnknown'), style: context.tt.headlineSmall),
          const SizedBox(height: 6),
          Text(context.s('scanUnknownSub', {'code': widget.code}), style: context.tt.bodyLarge!.copyWith(color: c.text2)),
        ],
        const SizedBox(height: 18),
        Text(context.s('scanName'), style: context.tt.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: _name, style: context.tt.titleLarge, textCapitalization: TextCapitalization.sentences, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        BigButton(label: context.s('scanAdd'), icon: Icons.add_rounded, onPressed: _name.text.trim().isEmpty ? null : _add),
        const SizedBox(height: 10),
        BigButton(label: context.s('scanAgain'), icon: Icons.qr_code_scanner_rounded, kind: BtnKind.secondary, onPressed: () => Navigator.pop(context)),
        const SizedBox(height: 14),
        Text(context.s('scanSource'), textAlign: TextAlign.center, style: context.tt.bodySmall),
      ]),
    );
  }
}
