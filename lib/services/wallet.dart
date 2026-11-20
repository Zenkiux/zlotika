import 'package:flutter/material.dart';

/// Loyalty cards the shopper can keep in the app. Only cards with a fixed number
/// printed as a barcode can be copied; app-only codes that change every minute
/// (Żappka) can't, so for those we open the shop's own app instead.
class CardType {
  const CardType(this.id, this.name, this.program, this.color, this.ink, {this.chain, this.appUrl, this.dynamicCode = false});
  final String id, name, program;
  final Color color, ink;
  final String? chain; // app chain id, so deals that need this card unlock
  final String? appUrl; // shop's own app / page
  final bool dynamicCode; // code in the shop's app changes; a copy wouldn't scan
}

const cardTypes = <CardType>[
  CardType('biedronka', 'Biedronka', 'Moja Biedronka', Color(0xFFD7172F), Colors.white, chain: 'biedronka', appUrl: 'https://www.biedronka.pl/pl/moja-biedronka'),
  CardType('kaufland', 'Kaufland', 'Kaufland Card', Color(0xFFE10915), Colors.white, chain: 'kaufland', appUrl: 'https://www.kaufland.pl/kaufland-card.html'),
  CardType('aldi', 'Aldi', 'ALDI', Color(0xFF00205B), Colors.white, chain: 'aldi', appUrl: 'https://www.aldi.pl/'),
  CardType('zabka', 'Żabka', 'Żappka', Color(0xFF1F7A3A), Colors.white, appUrl: 'https://www.zabka.pl/zappka', dynamicCode: true),
  CardType('lidl', 'Lidl', 'Lidl Plus', Color(0xFF0050AA), Color(0xFFFFF000), chain: 'lidl', appUrl: 'https://www.lidl.pl/c/lidl-plus/s10007388'),
  CardType('rossmann', 'Rossmann', 'Rossmann Klub', Color(0xFFC8102E), Colors.white, chain: 'rossmann', appUrl: 'https://www.rossmann.pl/'),
  CardType('other', 'Kita', '', Color(0xFF3A3D4A), Colors.white),
];

CardType cardTypeById(String id) => cardTypes.firstWhere((t) => t.id == id, orElse: () => cardTypes.last);

enum CodeFormat { ean13, ean8, code128, qr }

class LoyaltyCard {
  LoyaltyCard({required this.id, required this.type, required this.code, required this.format, this.label});
  final String id, type, code;
  final CodeFormat format;
  final String? label; // for "other" cards

  CardType get t => cardTypeById(type);
  String get title => label?.isNotEmpty == true ? label! : (t.program.isEmpty ? t.name : t.program);

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'code': code, 'format': format.name, 'label': label};
  factory LoyaltyCard.fromJson(Map<String, dynamic> j) => LoyaltyCard(
        id: j['id'] as String,
        type: j['type'] as String,
        code: j['code'] as String,
        format: CodeFormat.values.asNameMap()[j['format']] ?? CodeFormat.code128,
        label: j['label'] as String?,
      );

  /// Best format for a typed number: EAN-13/8 when the check digit is right, else Code 128.
  static CodeFormat guess(String code) {
    if (RegExp(r'^\d{13}$').hasMatch(code) && _eanOk(code)) return CodeFormat.ean13;
    if (RegExp(r'^\d{8}$').hasMatch(code) && _eanOk(code)) return CodeFormat.ean8;
    return CodeFormat.code128;
  }

  static bool _eanOk(String d) {
    var sum = 0;
    final body = d.substring(0, d.length - 1);
    for (var i = 0; i < body.length; i++) {
      final n = int.parse(body[body.length - 1 - i]);
      sum += i.isEven ? n * 3 : n;
    }
    return (10 - sum % 10) % 10 == int.parse(d[d.length - 1]);
  }
}

/// A fuel price the shopper saw at one station. Only theirs; never shared.
class SeenFuel {
  SeenFuel({this.pb95, this.diesel, this.lpg, required this.at});
  final double? pb95, diesel, lpg; // in the station's own currency
  final DateTime at;

  Map<String, dynamic> toJson() => {'pb95': pb95, 'diesel': diesel, 'lpg': lpg, 'at': at.toIso8601String()};
  factory SeenFuel.fromJson(Map<String, dynamic> j) => SeenFuel(
        pb95: (j['pb95'] as num?)?.toDouble(),
        diesel: (j['diesel'] as num?)?.toDouble(),
        lpg: (j['lpg'] as num?)?.toDouble(),
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}
