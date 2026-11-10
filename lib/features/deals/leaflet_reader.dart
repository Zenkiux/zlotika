import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/chains.dart';
import '../../services/deals.dart';

/// Network image that also works in the web build (retailer CDNs send no CORS headers).
class LeafletImage extends StatelessWidget {
  const LeafletImage(this.url, {super.key, this.fit = BoxFit.contain});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.network(
        url,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (c, child, p) => p == null ? child : const Center(child: CircularProgressIndicator(color: Brand.yellow, strokeWidth: 2.5)),
        errorBuilder: (c, _, _) => Center(child: Icon(Icons.broken_image_outlined, color: c.c.text3, size: 36)),
      );
}

/// Swipe through pages, pinch to zoom. Opens at [initialPage] (1-based).
class LeafletReader extends StatefulWidget {
  const LeafletReader({super.key, required this.leaflet, this.initialPage = 1});
  final Leaflet leaflet;
  final int initialPage;

  @override
  State<LeafletReader> createState() => _LeafletReaderState();
}

class _LeafletReaderState extends State<LeafletReader> {
  late final _pages = widget.leaflet.pages;
  late int _i = (_pages.indexWhere((p) => p.n == widget.initialPage)).clamp(0, _pages.length - 1);
  late final _ctl = PageController(initialPage: _i);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _go(int i) => _ctl.animateToPage(i.clamp(0, _pages.length - 1), duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final l = widget.leaflet;
    final chain = chainById(l.chain);
    final lang = context.lang;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(chain?.name ?? l.chain, style: context.tt.titleMedium!.copyWith(color: Colors.white)),
          Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall!.copyWith(color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            tooltip: context.s('lfOpenWeb'),
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => launchUrl(Uri.parse(_pages[_i].link), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _ctl,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) => InteractiveViewer(minScale: 1, maxScale: 5, child: LeafletImage(_pages[i].image)),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(children: [
              IconButton.filledTonal(onPressed: _i > 0 ? () => _go(_i - 1) : null, icon: const Icon(Icons.chevron_left_rounded, size: 30)),
              Expanded(
                child: Column(children: [
                  Text(context.s('lfPage', {'i': _i + 1, 'n': _pages.length}), style: context.tt.titleMedium!.copyWith(color: Colors.white)),
                  if (l.validTo != null)
                    Text(context.s('lfUntil', {'date': dayMonth(DateTime.parse(l.validTo!), lang)}), style: context.tt.bodySmall!.copyWith(color: Colors.white60)),
                ]),
              ),
              IconButton.filledTonal(onPressed: _i < _pages.length - 1 ? () => _go(_i + 1) : null, icon: const Icon(Icons.chevron_right_rounded, size: 30)),
            ]),
          ),
        ),
      ]),
    );
  }
}

void openLeaflet(BuildContext context, Leaflet l, {int page = 1}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeafletReader(leaflet: l, initialPage: page)));
