/// Approximate one-way road distances (km) along main roads via the nearest
/// open border crossing (Kalvarija–Budzisko or Lazdijai–Ogrodniki).
/// Production plan: replace with a precomputed OSRM matrix (docs/PLAN.md, D).
class Origin {
  const Origin(this.id, this.name, this.lat, this.lon, this.km);
  final String id, name;
  final double lat, lon;
  final Map<String, int> km;
}

class Destination {
  const Destination(this.id, this.name, this.lat, this.lon);
  final String id, name;
  final double lat, lon;
}

const destinations = [
  Destination('suwalki', 'Suwałki', 54.1115, 22.9308),
  Destination('augustow', 'Augustów', 53.8436, 22.9796),
  Destination('sejny', 'Sejny', 54.1093, 23.3463),
  Destination('bialystok', 'Białystok', 53.1325, 23.1688),
];

const origins = [
  Origin('vilnius', 'Vilnius', 54.6872, 25.2797, {'suwalki': 222, 'augustow': 245, 'sejny': 172, 'bialystok': 285}),
  Origin('kaunas', 'Kaunas', 54.8985, 23.9036, {'suwalki': 124, 'augustow': 154, 'sejny': 121, 'bialystok': 239}),
  Origin('alytus', 'Alytus', 54.3963, 24.0459, {'suwalki': 104, 'augustow': 128, 'sejny': 54, 'bialystok': 213}),
  Origin('marijampole', 'Marijampolė', 54.5593, 23.3541, {'suwalki': 66, 'augustow': 96, 'sejny': 72, 'bialystok': 181}),
  Origin('druskininkai', 'Druskininkai', 54.0157, 23.9717, {'suwalki': 112, 'augustow': 120, 'sejny': 62, 'bialystok': 205}),
  Origin('siauliai', 'Šiauliai', 55.9349, 23.3137, {'suwalki': 255, 'augustow': 285, 'sejny': 252, 'bialystok': 370}),
  Origin('panevezys', 'Panevėžys', 55.7348, 24.3575, {'suwalki': 230, 'augustow': 260, 'sejny': 227, 'bialystok': 345}),
  Origin('klaipeda', 'Klaipėda', 55.7033, 21.1443, {'suwalki': 330, 'augustow': 360, 'sejny': 327, 'bialystok': 445}),
];

Origin originById(String id) => origins.firstWhere((o) => o.id == id, orElse: () => origins[1]);
Destination destById(String id) => destinations.firstWhere((d) => d.id == id, orElse: () => destinations.first);
