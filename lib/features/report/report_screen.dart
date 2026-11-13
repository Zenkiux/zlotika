import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/calendar.dart' show isoDay;
import '../../data/chains.dart';
import '../../services/open_prices.dart';
import '../../services/stores.dart';
import '../../widgets/ui.dart';
import '../scan/scan_screen.dart';

/// Report a shelf price: barcode + price + shop + a photo of the price tag.
/// It goes to Open Prices (open data), so every Zlotika user — and anyone else — sees it.
class ReportPriceScreen extends StatefulWidget {
  const ReportPriceScreen({super.key, required this.item});
  final ListItem item;

  @override
  State<ReportPriceScreen> createState() => _ReportPriceScreenState();
}

class _ReportPriceScreenState extends State<ReportPriceScreen> {
  late final _price = TextEditingController(text: widget.item.plPrice?.toStringAsFixed(2).replaceAll('.', ','));
  late String? _barcode = widget.item.barcode;
  bool _discounted = false;
  Store? _store;
  File? _photo;
  String? _user;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    OpenPrices.user().then((u) => mounted ? setState(() => _user = u) : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store ??= _shops(AppScope.read(context)).firstOrNull;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  /// The trip's chosen shops first, then every other mapped shop in town.
  List<Store> _shops(AppState s) {
    final f = s.storeFeed;
    if (f == null) return const [];
    final picked = [for (final ch in s.tripChains) s.storeFor(ch)].whereType<Store>();
    final rest = f.stores.where((x) => x.town == s.destId && !x.isFuel && !picked.contains(x));
    return [...picked, ...rest].where((x) => OpenPrices.osmRef(x.id) != null).toList();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen(pickOnly: true)));
    if (code != null && mounted) setState(() => _barcode = code);
  }

  Future<void> _takePhoto(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 2000, imageQuality: 85);
    if (x != null && mounted) setState(() => _photo = File(x.path));
  }

  Future<void> _send() async {
    final s = AppScope.read(context);
    final price = parseAmount(_price.text);
    final ref = _store == null ? null : OpenPrices.osmRef(_store!.id);
    if (_barcode == null || price == null || ref == null || _photo == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OpenPrices.report(
        photo: _photo!,
        barcode: _barcode!,
        price: price,
        discounted: _discounted,
        osmId: ref.$1,
        osmType: ref.$2,
        date: isoDay(DateTime.now()),
      );
      // Also use it on this phone straight away.
      s.changeItem(widget.item.id, (i) {
        i.plPrice = price;
        i.barcode = _barcode;
        if (s.inTrip(_store!.chain)) i.chain = _store!.chain;
      });
      if (!mounted) return;
      final m = ScaffoldMessenger.of(context);
      final msg = context.s('repThanks');
      Navigator.pop(context);
      m.showSnackBar(SnackBar(content: Text(msg)));
    } on OpenPricesError catch (e) {
      if (e.code == 'auth') await OpenPrices.signOut();
      setState(() {
        _user = e.code == 'auth' ? null : _user;
        _error = context.s(e.code == 'auth' ? 'repErrAuth' : 'repErr');
      });
    } catch (_) {
      setState(() => _error = context.s('repErr'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final shops = _shops(s);
    final ready = _user != null && _barcode != null && parseAmount(_price.text) != null && _store != null && _photo != null;

    Widget step(int n, String title, Widget body, {bool done = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: done ? c.good : Brand.yellow,
                child: done ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : Text('$n', style: context.tt.labelMedium!.copyWith(color: Brand.ink)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: context.tt.titleMedium)),
            ]),
            const SizedBox(height: 10),
            body,
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(context.s('repTitle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(widget.item.name, style: context.tt.headlineSmall),
            if (widget.item.plName != null) ...[const SizedBox(height: 6), PlName(widget.item.plName!)],
            const SizedBox(height: 8),
            Text(context.s('repWhy'), style: context.tt.bodyMedium),
            const SizedBox(height: 20),
            if (_user == null) step(0, context.s('repAccount'), _SignIn(onDone: (u) => setState(() => _user = u))),
            step(
              1,
              context.s('repBarcode'),
              _barcode == null
                  ? BigButton(label: context.s('repScan'), icon: Icons.qr_code_scanner_rounded, kind: BtnKind.secondary, onPressed: _scan)
                  : Row(children: [
                      Expanded(child: Text(_barcode!, style: context.tt.titleLarge!.copyWith(letterSpacing: 2))),
                      TextButton(onPressed: _scan, child: Text(context.s('edit'))),
                    ]),
              done: _barcode != null,
            ),
            step(
              2,
              context.s('repPrice'),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: context.tt.headlineSmall,
                  decoration: const InputDecoration(hintText: '0,00', suffixText: 'zł'),
                  onChanged: (_) => setState(() {}),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _discounted,
                  onChanged: (v) => setState(() => _discounted = v ?? false),
                  title: Text(context.s('repDiscounted'), style: context.tt.bodyLarge),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ]),
              done: parseAmount(_price.text) != null,
            ),
            step(
              3,
              context.s('repShop'),
              shops.isEmpty
                  ? Text(context.s('repNoShops'), style: context.tt.bodyMedium)
                  : DropdownButtonFormField<Store>(
                      initialValue: _store,
                      isExpanded: true,
                      items: [
                        for (final st in shops)
                          DropdownMenuItem(
                            value: st,
                            child: Text('${chainById(st.chain)?.name ?? st.brand} · ${st.address ?? st.name ?? ''}', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => _store = v),
                    ),
              done: _store != null,
            ),
            step(
              4,
              context.s('repPhoto'),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_photo != null) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_photo!, height: 200, fit: BoxFit.cover)),
                  const SizedBox(height: 8),
                ],
                Row(children: [
                  Expanded(child: BigButton(label: context.s('repCamera'), icon: Icons.photo_camera_rounded, kind: BtnKind.secondary, onPressed: () => _takePhoto(ImageSource.camera))),
                  const SizedBox(width: 10),
                  Expanded(child: BigButton(label: context.s('repGallery'), icon: Icons.photo_library_rounded, kind: BtnKind.secondary, onPressed: () => _takePhoto(ImageSource.gallery))),
                ]),
                const SizedBox(height: 6),
                Text(context.s('repPhotoSub'), style: context.tt.bodySmall),
              ]),
              done: _photo != null,
            ),
            if (_error != null) ...[
              Panel(color: c.badSoft, child: Text(_error!, style: context.tt.bodyLarge)),
              const SizedBox(height: 12),
            ],
            BigButton(
              label: context.s(_busy ? 'repSending' : 'repSend'),
              icon: Icons.cloud_upload_rounded,
              onPressed: ready && !_busy ? _send : null,
            ),
            const SizedBox(height: 12),
            Text(context.s('repLicence', {'user': _user ?? '—'}), style: context.tt.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Open Food Facts sign-in. Also used from the More tab.
class _SignIn extends StatefulWidget {
  const _SignIn({required this.onDone});
  final ValueChanged<String> onDone;

  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  final _user = TextEditingController(), _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OpenPrices.signIn(_user.text, _pass.text);
      _pass.clear();
      widget.onDone(_user.text.trim());
    } on OpenPricesError catch (e) {
      setState(() => _error = context.s(e.code == 'auth' ? 'repErrLogin' : 'repErr'));
    } catch (_) {
      setState(() => _error = context.s('repErr'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.s('repAccountSub'), style: context.tt.bodyMedium),
        const SizedBox(height: 10),
        TextField(
          controller: _user,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          decoration: InputDecoration(hintText: context.s('repUser')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pass,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(hintText: context.s('repPass')),
          onSubmitted: (_) => _go(),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: context.tt.bodyMedium!.copyWith(color: context.c.bad))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: BigButton(label: context.s('repSignIn'), icon: Icons.login_rounded, onPressed: _busy ? null : _go)),
        ]),
        TextButton(
          onPressed: () => launchUrl(Uri.parse(OpenPrices.signUpUrl), mode: LaunchMode.externalApplication),
          child: Text(context.s('repSignUp')),
        ),
      ]);
}

/// Sign-in / sign-out block for the More tab.
class OpenPricesAccount extends StatefulWidget {
  const OpenPricesAccount({super.key});

  @override
  State<OpenPricesAccount> createState() => _OpenPricesAccountState();
}

class _OpenPricesAccountState extends State<OpenPricesAccount> {
  String? _user;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    OpenPrices.user().then((u) {
      if (mounted) {
        setState(() {
          _user = u;
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Panel(
      child: _user == null
          ? _SignIn(onDone: (u) => setState(() => _user = u))
          : Row(children: [
              Icon(Icons.verified_user_rounded, color: context.c.good),
              const SizedBox(width: 12),
              Expanded(child: Text(context.s('repSignedIn', {'user': _user!}), style: context.tt.titleMedium)),
              TextButton(
                onPressed: () async {
                  await OpenPrices.signOut();
                  setState(() => _user = null);
                },
                child: Text(context.s('repSignOut')),
              ),
            ]),
    );
  }
}
