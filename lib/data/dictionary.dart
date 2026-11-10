/// Hand-checked shopping vocabulary: Lithuanian · English · Polish (shelf wording).
/// Lets shoppers type in Lithuanian or English and see what to look for in Poland.
class Term {
  const Term(this.lt, this.en, this.pl, this.cat);
  final String lt, en, pl, cat;
}

const terms = <Term>[
  // Mėsa / meat
  Term('Vištienos krūtinėlė', 'Chicken breast', 'Filet z piersi kurczaka', 'meat'),
  Term('Vištienos šlaunelės', 'Chicken thighs', 'Udka z kurczaka', 'meat'),
  Term('Vištienos sparneliai', 'Chicken wings', 'Skrzydełka z kurczaka', 'meat'),
  Term('Kiaulienos sprandinė', 'Pork neck', 'Karkówka wieprzowa', 'meat'),
  Term('Kiaulienos nugarinė', 'Pork loin', 'Schab wieprzowy', 'meat'),
  Term('Kiaulienos šoninė', 'Pork belly', 'Boczek wieprzowy', 'meat'),
  Term('Kiaulienos šonkauliai', 'Pork ribs', 'Żeberka wieprzowe', 'meat'),
  Term('Malta mėsa', 'Minced meat', 'Mięso mielone', 'meat'),
  Term('Jautiena', 'Beef', 'Wołowina', 'meat'),
  Term('Kalakutiena', 'Turkey', 'Indyk', 'meat'),
  Term('Dešrelės', 'Sausages (frankfurters)', 'Parówki', 'meat'),
  Term('Dešra', 'Sausage', 'Kiełbasa', 'meat'),
  Term('Rūkyta dešra', 'Smoked sausage', 'Kiełbasa wędzona', 'meat'),
  Term('Kumpis', 'Ham', 'Szynka', 'meat'),
  Term('Kabanosai', 'Kabanos sticks', 'Kabanosy', 'meat'),
  Term('Lašiniai', 'Salo / pork fat', 'Słonina', 'meat'),
  Term('Žuvis', 'Fish', 'Ryba', 'meat'),
  Term('Lašiša', 'Salmon', 'Łosoś', 'meat'),
  Term('Silkė', 'Herring', 'Śledź', 'meat'),
  // Pieno produktai / dairy
  Term('Pienas', 'Milk', 'Mleko', 'dairy'),
  Term('Sviestas', 'Butter', 'Masło', 'dairy'),
  Term('Grietinė', 'Sour cream', 'Śmietana', 'dairy'),
  Term('Grietinėlė', 'Cream', 'Śmietanka', 'dairy'),
  Term('Varškė', 'Curd cheese', 'Twaróg', 'dairy'),
  Term('Sūris', 'Cheese', 'Ser żółty', 'dairy'),
  Term('Mocarela', 'Mozzarella', 'Mozzarella', 'dairy'),
  Term('Jogurtas', 'Yoghurt', 'Jogurt', 'dairy'),
  Term('Kefyras', 'Kefir', 'Kefir', 'dairy'),
  Term('Kiaušiniai', 'Eggs', 'Jajka', 'dairy'),
  Term('Margarinas', 'Margarine', 'Margaryna', 'dairy'),
  // Bakalėja / pantry
  Term('Kava', 'Coffee', 'Kawa', 'pantry'),
  Term('Malta kava', 'Ground coffee', 'Kawa mielona', 'pantry'),
  Term('Kavos pupelės', 'Coffee beans', 'Kawa ziarnista', 'pantry'),
  Term('Tirpi kava', 'Instant coffee', 'Kawa rozpuszczalna', 'pantry'),
  Term('Arbata', 'Tea', 'Herbata', 'pantry'),
  Term('Cukrus', 'Sugar', 'Cukier', 'pantry'),
  Term('Druska', 'Salt', 'Sól', 'pantry'),
  Term('Miltai', 'Flour', 'Mąka', 'pantry'),
  Term('Ryžiai', 'Rice', 'Ryż', 'pantry'),
  Term('Grikiai', 'Buckwheat', 'Kasza gryczana', 'pantry'),
  Term('Makaronai', 'Pasta', 'Makaron', 'pantry'),
  Term('Aliejus', 'Cooking oil', 'Olej', 'pantry'),
  Term('Saulėgrąžų aliejus', 'Sunflower oil', 'Olej słonecznikowy', 'pantry'),
  Term('Alyvuogių aliejus', 'Olive oil', 'Oliwa z oliwek', 'pantry'),
  Term('Majonezas', 'Mayonnaise', 'Majonez', 'pantry'),
  Term('Kečupas', 'Ketchup', 'Keczup', 'pantry'),
  Term('Garstyčios', 'Mustard', 'Musztarda', 'pantry'),
  Term('Šokoladas', 'Chocolate', 'Czekolada', 'pantry'),
  Term('Saldainiai', 'Sweets', 'Cukierki', 'pantry'),
  Term('Sausainiai', 'Biscuits', 'Ciastka', 'pantry'),
  Term('Traškučiai', 'Crisps', 'Chipsy', 'pantry'),
  Term('Riešutai', 'Nuts', 'Orzechy', 'pantry'),
  Term('Konservuoti pomidorai', 'Tinned tomatoes', 'Pomidory w puszce', 'pantry'),
  Term('Uogienė', 'Jam', 'Dżem', 'pantry'),
  Term('Medus', 'Honey', 'Miód', 'pantry'),
  Term('Duona', 'Bread', 'Chleb', 'pantry'),
  Term('Batonas', 'White loaf', 'Bułka / chleb pszenny', 'pantry'),
  Term('Vaisiai', 'Fruit', 'Owoce', 'pantry'),
  Term('Daržovės', 'Vegetables', 'Warzywa', 'pantry'),
  Term('Bulvės', 'Potatoes', 'Ziemniaki', 'pantry'),
  Term('Obuoliai', 'Apples', 'Jabłka', 'pantry'),
  Term('Bananai', 'Bananas', 'Banany', 'pantry'),
  Term('Svogūnai', 'Onions', 'Cebula', 'pantry'),
  Term('Morkos', 'Carrots', 'Marchew', 'pantry'),
  Term('Šaldyti koldūnai', 'Frozen dumplings', 'Pierogi mrożone', 'pantry'),
  // Gėrimai / drinks
  Term('Vanduo', 'Water', 'Woda', 'drinks'),
  Term('Gazuotas vanduo', 'Sparkling water', 'Woda gazowana', 'drinks'),
  Term('Negazuotas vanduo', 'Still water', 'Woda niegazowana', 'drinks'),
  Term('Sultys', 'Juice', 'Sok', 'drinks'),
  Term('Gaivusis gėrimas', 'Soft drink', 'Napój gazowany', 'drinks'),
  Term('Alus', 'Beer', 'Piwo', 'drinks'),
  Term('Vynas', 'Wine', 'Wino', 'drinks'),
  Term('Degtinė', 'Vodka', 'Wódka', 'drinks'),
  // Higiena ir kosmetika / hygiene & cosmetics
  Term('Dantų pasta', 'Toothpaste', 'Pasta do zębów', 'hygiene'),
  Term('Dantų šepetėlis', 'Toothbrush', 'Szczoteczka do zębów', 'hygiene'),
  Term('Šampūnas', 'Shampoo', 'Szampon', 'hygiene'),
  Term('Plaukų kondicionierius', 'Conditioner', 'Odżywka do włosów', 'hygiene'),
  Term('Dušo želė', 'Shower gel', 'Żel pod prysznic', 'hygiene'),
  Term('Muilas', 'Soap', 'Mydło', 'hygiene'),
  Term('Skystas muilas', 'Liquid soap', 'Mydło w płynie', 'hygiene'),
  Term('Dezodorantas', 'Deodorant', 'Dezodorant', 'hygiene'),
  Term('Higieniniai paketai', 'Sanitary pads', 'Podpaski higieniczne', 'hygiene'),
  Term('Tamponai', 'Tampons', 'Tampony', 'hygiene'),
  Term('Įklotai', 'Panty liners', 'Wkładki higieniczne', 'hygiene'),
  Term('Tualetinis popierius', 'Toilet paper', 'Papier toaletowy', 'hygiene'),
  Term('Popierinės nosinės', 'Tissues', 'Chusteczki higieniczne', 'hygiene'),
  Term('Drėgnos servetėlės', 'Wet wipes', 'Chusteczki nawilżane', 'hygiene'),
  Term('Skutimosi peiliukai', 'Razors', 'Maszynki do golenia', 'hygiene'),
  Term('Skutimosi putos', 'Shaving foam', 'Pianka do golenia', 'hygiene'),
  Term('Veido kremas', 'Face cream', 'Krem do twarzy', 'hygiene'),
  Term('Rankų kremas', 'Hand cream', 'Krem do rąk', 'hygiene'),
  Term('Kūno losjonas', 'Body lotion', 'Balsam do ciała', 'hygiene'),
  Term('Apsauginis kremas nuo saulės', 'Sunscreen', 'Krem z filtrem', 'hygiene'),
  Term('Plaukų dažai', 'Hair dye', 'Farba do włosów', 'hygiene'),
  Term('Makiažo valiklis', 'Make-up remover', 'Płyn do demakijażu', 'hygiene'),
  Term('Vata', 'Cotton pads', 'Płatki kosmetyczne', 'hygiene'),
  // Buitinė chemija / household
  Term('Skalbimo milteliai', 'Washing powder', 'Proszek do prania', 'household'),
  Term('Skalbimo kapsulės', 'Laundry pods', 'Kapsułki do prania', 'household'),
  Term('Skalbimo gelis', 'Laundry gel', 'Żel do prania', 'household'),
  Term('Audinių minkštiklis', 'Fabric softener', 'Płyn do płukania', 'household'),
  Term('Indų ploviklis', 'Washing-up liquid', 'Płyn do mycia naczyń', 'household'),
  Term('Indaplovės tabletės', 'Dishwasher tablets', 'Tabletki do zmywarki', 'household'),
  Term('Valymo priemonė', 'Cleaner', 'Środek czyszczący', 'household'),
  Term('Tualeto valiklis', 'Toilet cleaner', 'Żel do WC', 'household'),
  Term('Šiukšlių maišai', 'Bin bags', 'Worki na śmieci', 'household'),
  Term('Popieriniai rankšluosčiai', 'Paper towels', 'Ręczniki papierowe', 'household'),
  Term('Folija', 'Cling film', 'Folia spożywcza', 'household'),
  Term('Baterijos', 'Batteries', 'Baterie', 'household'),
  Term('Kačių maistas', 'Cat food', 'Karma dla kota', 'household'),
  Term('Šunų maistas', 'Dog food', 'Karma dla psa', 'household'),
  Term('Kraikas katėms', 'Cat litter', 'Żwirek dla kota', 'household'),
  // Kūdikiams / baby
  Term('Sauskelnės', 'Nappies', 'Pieluchy', 'baby'),
  Term('Sauskelnės-kelnaitės', 'Nappy pants', 'Pieluchomajtki', 'baby'),
  Term('Kūdikių mišinys', 'Baby formula', 'Mleko modyfikowane', 'baby'),
  Term('Kūdikių tyrelė', 'Baby food jar', 'Słoiczek dla dzieci', 'baby'),
  Term('Kūdikių servetėlės', 'Baby wipes', 'Chusteczki dla dzieci', 'baby'),
  // Drabužiai ir kita / clothes & other
  Term('Kojinės', 'Socks', 'Skarpety', 'other'),
  Term('Apatiniai', 'Underwear', 'Bielizna', 'other'),
  Term('Marškinėliai', 'T-shirt', 'Koszulka', 'other'),
  Term('Džemperis', 'Sweatshirt', 'Bluza', 'other'),
  Term('Pižama', 'Pyjamas', 'Piżama', 'other'),
  Term('Batai', 'Shoes', 'Buty', 'other'),
  Term('Knyga', 'Book', 'Książka', 'other'),
  Term('Žaislas', 'Toy', 'Zabawka', 'other'),
  Term('Vitaminai', 'Vitamins', 'Witaminy', 'other'),
  Term('Vaistai nuo skausmo', 'Painkillers', 'Leki przeciwbólowe', 'other'),
];

/// Popular cross-border buys, shown before the user types.
const popularIds = [
  'Vištienos krūtinėlė', 'Kiaulienos sprandinė', 'Sviestas', 'Malta kava', 'Sūris', 'Skalbimo kapsulės',
  'Sauskelnės', 'Šampūnas', 'Dantų pasta', 'Tualetinis popierius', 'Indaplovės tabletės', 'Higieniniai paketai',
];

String _fold(String s) {
  const from = 'ąčęėįšųūžłńóśźżć';
  const to = 'aceeisuuzlnoszzc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

/// Matches Lithuanian, English or Polish words, ignoring diacritics and endings.
List<Term> searchTerms(String q) {
  final query = _fold(q.trim());
  if (query.isEmpty) return const [];
  final words = query.split(RegExp(r'\s+')).map((w) => w.length > 5 ? w.substring(0, w.length - 2) : w).toList();
  final scored = <(Term, int)>[];
  for (final t in terms) {
    final hay = _fold('${t.lt} ${t.en} ${t.pl}');
    var score = 0;
    var all = true;
    for (final w in words) {
      if (RegExp('(^|[^a-z])$w').hasMatch(hay)) {
        score += 2;
      } else if (hay.contains(w)) {
        score += 1;
      } else {
        all = false;
        break;
      }
    }
    if (all) scored.add((t, score + (_fold(t.lt).startsWith(query) ? 3 : 0)));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return scored.map((e) => e.$1).take(8).toList();
}

Term? termByLt(String lt) {
  for (final t in terms) {
    if (t.lt == lt) return t;
  }
  return null;
}

/// Best-effort translation of a Polish product title: the dictionary term whose
/// Polish words all appear in the title (longest match wins). Null if unsure.
Term? guessTerm(String polishTitle) {
  final hay = _fold(polishTitle);
  Term? best;
  var bestLen = 0;
  for (final t in terms) {
    final words = _fold(t.pl).split(RegExp(r'[^a-z]+')).where((w) => w.length > 2).toList();
    if (words.isEmpty) continue;
    final ok = words.every((w) => RegExp('(^|[^a-z])${w.length > 6 ? w.substring(0, w.length - 2) : w}').hasMatch(hay));
    final len = words.join().length;
    if (ok && len > bestLen) {
      best = t;
      bestLen = len;
    }
  }
  return best;
}

/// Diacritic-insensitive text for searching deals.
String foldText(String s) => _fold(s);
