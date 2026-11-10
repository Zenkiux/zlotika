import 'package:flutter/material.dart';

/// Polish retail chains: display colours and the official leaflet page.
/// Linking to a retailer's own leaflet page never copies their content.
class Chain {
  const Chain(this.id, this.name, this.color, this.ink, this.leafletUrl, {this.card});
  final String id, name;
  final Color color, ink;
  final String leafletUrl;
  final String? card; // loyalty card / app name, if promos often need it
}

const chains = <Chain>[
  Chain('biedronka', 'Biedronka', Color(0xFFD7172F), Color(0xFFFFE600), 'https://www.biedronka.pl/pl/gazetki', card: 'Moja Biedronka'),
  Chain('lidl', 'Lidl', Color(0xFF0050AA), Color(0xFFFFF000), 'https://www.lidl.pl/c/nasze-gazetki/s10008614', card: 'Lidl Plus'),
  Chain('kaufland', 'Kaufland', Color(0xFFE10915), Colors.white, 'https://www.kaufland.pl/gazetka.html', card: 'Kaufland Card'),
  Chain('rossmann', 'Rossmann', Color(0xFFC8102E), Colors.white, 'https://www.rossmann.pl/promocje', card: 'Rossmann Klub'),
  Chain('hebe', 'Hebe', Color(0xFFE6007E), Colors.white, 'https://www.hebe.pl/promocje/'),
  Chain('aldi', 'Aldi', Color(0xFF00205B), Colors.white, 'https://www.aldi.pl/gazetki.html'),
  Chain('netto', 'Netto', Color(0xFFFFD200), Color(0xFF1A1A1A), 'https://www.netto.pl/gazetki/'),
  Chain('auchan', 'Auchan', Color(0xFFE2001A), Colors.white, 'https://www.auchan.pl/pl/gazetki'),
  Chain('carrefour', 'Carrefour', Color(0xFF004E9F), Colors.white, 'https://www.carrefour.pl/gazetka'),
  Chain('pepco', 'Pepco', Color(0xFF1D1D1B), Colors.white, 'https://pepco.pl/gazetka/'),
  Chain('action', 'Action', Color(0xFF0070C0), Colors.white, 'https://www.action.com/pl-pl/'),
  Chain('dino', 'Dino', Color(0xFF00843D), Colors.white, 'https://grupadino.pl/gazetki/'),
];

Chain? chainById(String id) {
  for (final c in chains) {
    if (c.id == id) return c;
  }
  return null;
}
