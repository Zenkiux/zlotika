import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// App UI languages: Lithuanian (primary) and English. Polish appears only as
/// product names and the staff card, never as UI language.
enum Lang { lt, en }

const _lt = <String, String>{
  'tagline': 'Apsipirk Lenkijoje išmaniau.',
  'next': 'Toliau', 'back': 'Atgal', 'save': 'Išsaugoti', 'cancel': 'Atšaukti', 'delete': 'Ištrinti',
  'done': 'Baigta', 'add': 'Pridėti', 'close': 'Uždaryti', 'retry': 'Bandyti dar kartą', 'edit': 'Keisti', 'undo': 'Grąžinti',

  'tabHome': 'Pradžia', 'tabList': 'Sąrašas', 'tabTrip': 'Kelionė', 'tabMore': 'Daugiau',

  'helloMorning': 'Labas rytas', 'helloDay': 'Laba diena', 'helloEvening': 'Labas vakaras',
  'today': 'Šiandien Lenkijoje',
  'rateTitle': 'Euro kursas', 'rateSource': 'NBP, {date}', 'rateLoading': 'Gauname kursą…',
  'rateStale': 'Rodomas paskutinis žinomas kursas', 'rateNone': 'Kurso dar nėra. Prisijunkite prie interneto.',
  'shopsOpen': 'Šiandien prekybos diena', 'shopsSunday': 'Sekmadienis: parduotuvės nedirba', 'shopsHoliday': 'Šventė: parduotuvės nedirba',
  'shopsTradingSunday': 'Prekybos sekmadienis: dirba', 'shopsNext': 'Artimiausias šeštadienis {date}',
  'shopsNextClosed': 'Dėmesio: {date} parduotuvės nedirba',
  'timeThere': 'Lenkijoje dabar {time}', 'timeThereSub': 'Valanda mažiau nei Lietuvoje',
  'actionList': 'Pirkinių sąrašas', 'actionTrip': 'Ar verta važiuoti?', 'actionTripSub': 'Apskaičiuosime naudą',
  'actionScan': 'Nuskenuoti prekę', 'actionScanSub': 'Sužinokite, kas tai', 'actionConvert': 'Zlotai į eurus', 'actionConvertSub': 'Kiek tai kainuoja?',
  'tipTitle': 'Naudingas patarimas',
  'tipPay': 'Mokėdami kortele visada rinkitės zlotus (PLN), ne eurus. Kitaip bankas gali taikyti 3–7 % blogesnį kursą.',
  'tipDeposit': 'Už plastikinius butelius ir skardines Lenkijoje imamas 0,50 zł užstatas. Jį atgausite tik grąžinę tarą Lenkijoje.',
  'tipTime': 'Lenkijoje laikas valanda mažiau. Jei parduotuvė dirba iki 21:00, Lietuvos laiku tai 22:00.',

  'listTitle': 'Pirkinių sąrašas', 'listEmpty': 'Sąrašas tuščias',
  'listEmptySub': 'Įrašykite, ką norite nupirkti Lenkijoje. Šalia parodysime lenkišką pavadinimą, kad lengvai rastumėte prekę.',
  'listAdd': 'Pridėti prekę', 'listScan': 'Skenuoti',
  'listInPl': 'Lenkijoje', 'listInLt': 'Lietuvoje', 'listSave': 'Sutaupysite',
  'matchCount': '{n} akc. nuo {v}', 'matchPickTitle': 'Akcijos šią savaitę: {name}',
  'matchPickSub': 'Pasirinkite, kurią pirksite – kainą įrašysime už jus.', 'matchNone': 'Pridėti be kainos',
  'itemNeedLt': 'Įrašykite LT kainą', 'listPlOnly': 'Lenkijoje kainuos apie',
  'listPlOnlySub': 'Kainos iš akcijų ({n}/{m}). Įrašykite, kiek tai kainuoja Lietuvoje, ir parodysime, kiek sutaupysite.',
  'listMissing': 'Dar trūksta kainų: {n}', 'listNoPrices': 'Įrašykite kainas, ir apskaičiuosime, kiek sutaupysite.',
  'listClearChecked': 'Pašalinti nupirktas', 'itemAddPrices': 'Įrašyti kainas',
  'itemPricePl': 'Kaina Lenkijoje', 'itemPriceLt': 'Kaina Lietuvoje', 'itemQty': 'Kiekis',
  'itemSaving': 'Sutaupysite {v}', 'itemCheaperLt': 'Lietuvoje pigiau {v}', 'itemSame': 'Kaina panaši',
  'itemPlName': 'Lenkiškai', 'itemShowStaff': 'Rodyti pardavėjui', 'itemDelete': 'Pašalinti iš sąrašo',
  'itemRemoved': '„{name}“ pašalinta', 'itemEach': 'už vienetą',
  'addTitle': 'Ką norite nupirkti?', 'addHint': 'Pvz., sviestas, kava, sauskelnės', 'addCustom': 'Pridėti „{q}“',
  'addPopular': 'Dažnai perkama Lenkijoje', 'addNoPl': 'be lenkiško vertimo', 'addAdded': 'Pridėta: {name}',
  'staffHint': 'Parodykite šį ekraną parduotuvės darbuotojui', 'staffTranslation': 'Lietuviškai: {name}',

  'tripTitle': 'Ar verta važiuoti?', 'tripStep': '{i} žingsnis iš {n}',
  'tripFrom': 'Iš kur važiuosite?', 'tripTo': 'Į kurį miestą važiuosite?', 'tripCar': 'Koks jūsų automobilis?',
  'tripPeople': 'Kiek žmonių važiuos?', 'tripPeopleSub': 'Kelionės kainą padalinsime visiems.',
  'tripFuel': 'Kiek kainuoja degalai?', 'tripFuelSub': 'Įrašėme naujausias vidutines kainas. Jei degalinėje matote kitą, tiesiog įrašykite savo.',
  'fuelAuto': 'Šalies vidurkis · {src}, {date}', 'fuelAutoRegion': 'Vidurkis ({region}) · {src}, {date}', 'fuelAutoConverted': ' · perskaičiuota pagal NBP kursą',
  'fuelUseAuto': 'Naudoti vidurkį: {v}', 'srcEuBulletin': 'ES naftos biuletenis',
  'fuelDiesel': 'Dyzelinas', 'fuelPetrol': 'Benzinas', 'fuelLpg': 'Dujos',
  'consumption': 'Sunaudoja 100 km', 'refuel': 'Kiek litrų pilsite Lenkijoje?', 'refuelNone': 'Nepilsiu',
  'fuelLt': 'Lietuvoje, € už litrą', 'fuelPl': 'Lenkijoje, zł už litrą',
  'srcLt': 'Lietuvos kainos: degalukainos.ena.lt', 'srcPl': 'Lenkijos kainos: e-petrol.pl',
  'resultWorth': 'Taip, verta važiuoti', 'resultMarginal': 'Nauda nedidelė', 'resultNot': 'Ne, neapsimoka',
  'resultWorthSub': 'Sutaupysite daugiau, nei kainuos kelionė.',
  'resultMarginalSub': 'Kelionė vos atsiperka. Papildykite sąrašą arba važiuokite su kaimynais.',
  'resultNotSub': 'Kelionė kainuos daugiau, nei sutaupysite.',
  'resultNet': 'Jūsų nauda', 'resultPerPerson': '{v} kiekvienam',
  'rowDistance': 'Kelionė į abi puses', 'rowFuelTrip': 'Degalai kelionei', 'rowShopping': 'Pigiau apsipirksite',
  'rowRefuel': 'Pigiau pripilsite baką', 'rowTotal': 'Iš viso', 'rowShoppingNone': 'Įrašykite kainas sąraše',
  'breakEven': 'Kelionė atsiperka, jei Lenkijoje nupirksite prekių, kurios Lietuvoje kainuotų daugiau nei {v}.',
  'resultEdit': 'Keisti duomenis', 'resultMaps': 'Atidaryti žemėlapį', 'resultToList': 'Papildyti sąrašą',
  'estimate': 'Skaičiavimas apytikslis: atstumas pagal kelią, degalų kainos – savaitės vidurkiai arba jūsų įrašytos.',
  'tripSunday': 'Šį sekmadienį Lenkijos parduotuvės nedirba. Važiuokite šeštadienį.',

  'convTitle': 'Zlotai į eurus', 'convPln': 'Zlotai', 'convEur': 'Eurai', 'convFee': 'Banko kortelės mokestis',
  'convFeeSub': 'Pvz., Revolut darbo dienomis 0 %, kai kurie bankai 1–3 %', 'convRate': '1 € = {r} zł · NBP, {d}',
  'convQuick': 'Greitai pasitikrinti',

  'scanTitle': 'Nuskenuokite kodą', 'scanHint': 'Nukreipkite kamerą į brūkšninį kodą ant pakuotės',
  'scanLooking': 'Ieškome produkto…', 'scanUnknown': 'Šio produkto duomenų bazėje dar nėra',
  'scanUnknownSub': 'Kodas {code}. Galite įrašyti pavadinimą patys.', 'scanAdd': 'Įdėti į sąrašą', 'scanAgain': 'Skenuoti kitą',
  'scanSource': 'Duomenys: Open Food Facts (ODbL)', 'scanNoCamera': 'Kamera neįsijungė. Leiskite ją naudoti arba įveskite kodą ranka.',
  'scanManual': 'Įvesti kodą ranka', 'scanFind': 'Ieškoti', 'scanOffline': 'Nėra ryšio. Bandykite vėliau.', 'scanName': 'Pavadinimas',

  'moreTitle': 'Daugiau', 'setLang': 'Kalba', 'setText': 'Teksto dydis', 'textNormal': 'Įprastas', 'textLarge': 'Didelis', 'textXL': 'Labai didelis',
  'setTheme': 'Išvaizda', 'themeDark': 'Tamsi', 'themeLight': 'Šviesi', 'themeSystem': 'Kaip telefone',
  'setHome': 'Namų miestas', 'setCar': 'Automobilis', 'setFee': 'Kortelės mokestis', 'setPreview': 'Taip atrodys tekstas',
  'aboutData': 'Iš kur duomenys?', 'privacy': 'Privatumas', 'aboutApp': 'Apie Zlotika',
  'aboutAppText': 'Zlotika nemokama, be reklamų ir be paskyrų. Ji nesusijusi su jokiu prekybos tinklu.',
  'privacyText': 'Paskyros nereikia. Jūsų sąrašas ir nustatymai saugomi tik šiame telefone. Vietos neprašome — miestą pasirenkate patys. Kamera naudojama tik kodui nuskaityti.',
  'dataNbp': 'Valiutos kursas — Lenkijos nacionalinis bankas (NBP), atnaujinama darbo dienomis.',
  'dataOff': 'Produktai pagal brūkšninį kodą — Open Food Facts, licencija ODbL.',
  'dataCalendar': 'Prekybos sekmadieniai ir šventės — pagal Lenkijos įstatymus, įrašyta programoje.',
  'dataDistance': 'Atstumai — apytiksliai, pagal pagrindinius kelius.',
  'dataPrices': 'Degalų kainos – oficialūs savaitės vidurkiai (ES naftos biuletenis, e-petrol.pl). Lenkiškų prekių kainos – iš šios savaitės akcijų, o įprastos kainos – iš Rossmann parduotuvės svetainės. Įprastos Lietuvos kainos – iš Barbora.lt (Maxima internetinė parduotuvė), atnaujinamos kasdien; jos pažymėtos „≈“. Visada galite įrašyti savo kainą. Parduotuvių vietos – © OpenStreetMap bendraautoriai; darbo laikas – iš tinklų svetainių (Lidl, Aldi, Rossmann, Pepco, Dino, Netto) arba OpenStreetMap.',
  'resetAll': 'Ištrinti visus mano duomenis', 'resetQ': 'Ištrinti viską?', 'resetSub': 'Bus ištrintas sąrašas ir nustatymai šiame telefone.',
  'version': 'Versija {v}',

  'obWelcome': 'Sveiki!', 'obWelcomeSub': 'Zlotika padės nuspręsti, ar verta važiuoti apsipirkti į Lenkiją, ir kiek sutaupysite.',
  'obTextSub': 'Pasirinkite patogų teksto dydį. Pakeisti galėsite bet kada.',
  'obHome': 'Iš kurio miesto važiuojate?', 'obHomeSub': 'Pagal tai skaičiuosime kelionės kainą.', 'obStart': 'Pradėti',

  'tabDeals': 'Akcijos', 'dealsTitle': 'Šios savaitės akcijos', 'dealsUpdated': 'Iš parduotuvių svetainių · atnaujinta {ago}',
  'agoNow': 'ką tik', 'agoH': 'prieš {n} val.', 'agoD': 'prieš {n} d.',
  'dealsSearch': 'Ieškoti akcijose', 'dealsAll': 'Visos', 'dealsTabDeals': 'Akcijos', 'dealsTabLeaflets': 'Leidiniai',
  'dealsEmpty': 'Akcijų kol kas nėra', 'dealsEmptySub': 'Akcijų sąrašą atnaujiname kasdien. Kol kas peržiūrėkite oficialius parduotuvių leidinius.',
  'dealsShowLeaflets': 'Rodyti leidinius', 'dealsNone': 'Nieko neradome', 'dealsLoading': 'Įkeliamos akcijos…',
  'dealsCard': 'Su {card}', 'dealsCardGeneric': 'Reikia kortelės ar programėlės', 'dealsMinQty': 'Perkant nuo {n} vnt.', 'dealsLimit': 'Iki {n} vnt. vienam pirkėjui',
  'dealsUntil': 'iki {date}', 'dealsFix': 'Jūsų pataisa', 'dealsTranslated': 'Lietuviškai',
  'dealAdd': 'Įdėti į sąrašą', 'dealFixTitle': 'Kaina parduotuvėje kitokia?', 'dealFixHint': 'Įrašykite kainą, kurią matote. Ji bus naudojama jūsų skaičiavimuose.',
  'dealFixSave': 'Išsaugoti kainą', 'dealFixClear': 'Grąžinti pradinę kainą', 'dealOpen': 'Atidaryti parduotuvės puslapį',
  'dealSource': 'Kaina paimta iš {chain} svetainės. Parduotuvėje ji gali skirtis.', 'dealPerUnit': '{v} už {unit}',
  'leafletsTitle': 'Oficialūs parduotuvių leidiniai', 'leafletsSub': 'Atsidarys parduotuvės svetainėje.', 'leafletOpen': 'Atidaryti leidinį',
  'homeDeals': 'Šios savaitės akcijos', 'homeDealsSub': '{n} akcijų iš Lenkijos parduotuvių',

  'lfPages': '{n} psl.', 'lfUntil': 'galioja iki {date}', 'lfOpenWeb': 'Atidaryti svetainėje', 'lfOther': 'Kitų parduotuvių leidiniai',
  'lfOtherSub': 'Šių parduotuvių leidinius atidarysime jų svetainėje.', 'lfPage': '{i} iš {n}', 'lfNone': 'Leidinių kol kas nėra',
  'lfLoading': 'Įkeliamas puslapis…', 'lfError': 'Puslapio nepavyko įkelti', 'lfHint': 'Suimkite dviem pirštais, kad padidintumėte',
  'dealOcr': 'Iš leidinio', 'dealOcrNote': 'Pavadinimas ir kaina atpažinti automatiškai iš leidinio. Prieš pirkdami patikrinkite puslapyje.',
  'dealSeePage': 'Žiūrėti leidinio puslapį',
  // Trip plan
  'planTitle': 'Kelionės planas', 'planHome': 'Planuoti kelionę', 'planHomeSub': 'Parduotuvės, darbo laikas, kainos ir maršrutas',
  'planToday': 'Šiandien', 'planTomorrow': 'Rytoj', 'planClosedShort': 'nedirba',
  'planDaySunday': 'Tą dieną sekmadienis – Lenkijoje parduotuvės nedirba (veikia tik degalinės). Pasirinkite kitą dieną.',
  'planDayHoliday': 'Tą dieną Lenkijoje šventė – parduotuvės nedirba. Pasirinkite kitą dieną.',
  'planDrive': 'Į vieną pusę {km} km, apie {h} val. kelio',
  'planHours': 'Visos jūsų parduotuvės dirba nuo {from} iki {to}',
  'planLeaveBy': 'Išvykite ne vėliau kaip {t} Lietuvos laiku, kad spėtumėte visur',
  'planLate': 'Šiandien jau per vėlu spėti visur (reikėjo išvykti iki {t}). Rinkitės rytojų.',
  'planTz': 'Lenkijoje laikas valanda mažiau. Šalia rodome ir Lietuvos laiką.',
  'planSpend': 'Lenkijoje išleisite apie', 'planGuessed': 'Iš jų {n} – pagal praeitą kartą mokėtą kainą',
  'planUnknown': 'Dar nežinoma kaina: {n}', 'planNet': 'Kelionės nauda {v} · plačiau',
  'planEmpty': 'Pirmiausia įrašykite, ką norite nupirkti.',
  'planStops': 'Sustojimai ({n})', 'planLoose': 'Dar nepasirinkta parduotuvė',
  'planLooseSub': 'Paspauskite prekę ir pasirinkite akciją arba parduotuvę – įtrauksime į maršrutą.',
  'planRoute': 'Maršrutas per visas parduotuves', 'planChecklist': 'Prieš išvykstant: patikrinkite',
  'planOsm': 'Parduotuvių vietos ir darbo laikas: © OpenStreetMap bendraautoriai ({date}). Darbo laikas gali keistis – svarbiais atvejais pasitikrinkite.',
  'planFuel': 'Degalinė', 'planFuelLitres': 'Įpilti apie {l} l',
  'planNoShop': 'Šio tinklo parduotuvės mieste {town} nežinome', 'planNoAddress': 'Adresas nežinomas',
  'planOtherShop': 'Kita parduotuvė', 'planSubtotal': 'Šioje parduotuvėje', 'planNoPrice': 'kaina ?', 'planLastTime': 'praeitą kartą ({d})',
  'hoursClosed': 'Tą dieną nedirba', 'hours247': 'Dirba visą parą', 'hoursUnknown': 'Darbo laikas nežinomas', 'hoursClosedNow': 'Šiandien jau uždaryta',
  'hoursOpenUntil': 'Dabar dirba iki {t} (LT {lt})', 'hoursOpensAt': 'Dirbs {t}–{c} (LT {lt}–{lc})',
  'hoursGuessed': 'Įprastas šio tinklo laikas mieste – šios parduotuvės tikslaus nežinome.',
  'itemWhere': 'Kur pirksite?', 'itemWhereAny': 'Dar nežinau',

  // Checklist
  'ckTitle': 'Prieš išvykstant', 'ckProgress': 'Pažymėta {n} iš {m}',
  'ckDocs': 'Dokumentai', 'ckRoad': 'Kelyje Lenkijoje', 'ckShop': 'Apsiperkant', 'ckSafety': 'Saugumas',
  'ckId': 'Asmens tapatybės kortelė arba pasas', 'ckIdSub': 'Lenkijoje privaloma turėti asmens dokumentą. Pasienyje gali būti tikrinama.',
  'ckLicence': 'Vairuotojo pažymėjimas ir automobilio dokumentai', 'ckLicenceSub': 'Patikrinkite, ar galioja techninė apžiūra ir privalomasis draudimas.',
  'ckLights': 'Artimosios šviesos visą parą', 'ckLightsSub': 'Lenkijoje jos privalomos ir dieną.',
  'ckAlcohol': 'Alkoholio riba – 0,2 ‰', 'ckAlcoholSub': 'Lenkijoje griežčiau nei Lietuvoje. Saugiausia – visai negerti.',
  'ckSpeed': 'Greitis: 50 / 90 / 120 / 140 km/h', 'ckSpeedSub': 'Gyvenvietėje 50, užmiestyje 90, greitkelyje (S) iki 120, autostradoje 140. Kelyje daug greičio kamerų.',
  'ckBags': 'Krepšiai pirkiniams', 'ckBagsSub': 'Maišeliai parduotuvėse mokami.',
  'ckCard': 'Mokėkite zlotais', 'ckCardSub': 'Kortelės terminale rinkitės PLN, ne EUR – kitaip kursas būna 3–7 % blogesnis.',
  'ckDeposit': 'Tara su užstatu', 'ckDepositSub': 'Už butelius ir skardines Lenkijoje imamas užstatas. Atgausite tik grąžinę tarą Lenkijoje.',
  'ckLimits': 'Kiek galima parsivežti', 'ckLimitsSub': 'ES orientyrai asmeniniam naudojimui: 800 cigarečių, 1 kg tabako, 10 l stipriųjų gėrimų, 20 l tarpinių produktų, 90 l vyno (iš jo iki 60 l putojančio), 110 l alaus. Degalai – bake ir iki 10 l kanistre. Daugiau muitinė gali laikyti prekyba.',
  'ckLimitsLink': 'Muitinės informacija', 'ck112': 'Pagalbos numeris – 112', 'ck112Sub': 'Veikia ir Lenkijoje. Žemiau – kortelė lenkiškai, jei reikėtų pagalbos.',
  'ckNote': 'Bendra informacija, ne teisinė konsultacija. Taisyklės gali keistis.',
  'sosOpen': 'SOS kortelė lenkiškai', 'sosCall': 'Skambinti 112',
  'sosTranslation': 'Lietuviškai: „Man reikia pagalbos. Prašau paskambinti 112. Esu iš Lietuvos, nekalbu lenkiškai.“',

  // Watchlist
  'watchTitle': 'Stebimos prekės', 'watchHome': 'Stebimos prekės', 'watchHomeSub': 'Pranešime, kai atsiras akcija',
  'watchHomeHits': 'Šią savaitę akcijų: {n}',
  'watchSub': 'Įrašykite, ką perkate nuolat. Kai Lenkijos parduotuvėse atsiras akcija, pranešime.',
  'watchAlerts': 'Pranešti apie naujas akcijas', 'watchAlertsSub': 'Telefonas tikrina kelis kartus per dieną. Nieko nesiunčiame į serverį.',
  'watchNoPermission': 'Pranešimai neleisti. Įjunkite juos telefono nustatymuose.',
  'watchHint': 'Pvz., kava, Pampers, Jacobs', 'watchCustom': 'Stebėti „{q}“', 'watchCustomSub': 'Ieškosime šių žodžių akcijų pavadinimuose (tinka ir prekės ženklai)',
  'watchEmpty': 'Dar nieko nestebite.', 'watchNoDeals': 'Šiuo metu akcijų nėra', 'watchAdd': 'Stebėti akcijas', 'watchAdded': 'Stebima: {name}',
  'alertOne': 'Akcija jūsų stebimai prekei', 'alertMany': 'Akcijos jūsų stebimoms prekėms: {n}',

  // History
  'histTitle': 'Sutaupymai', 'histYear': '{y} m. sutaupėte', 'histYearSub': 'Kelionių: {n} · išleista Lenkijoje {v}',
  'histHow': 'Skaičiuojame tik prekes, kurių kainą Lietuvoje žinome, ir atimame kelionės degalus.',
  'histEmpty': 'Grįžę iš Lenkijos paspauskite „Baigiau apsipirkti“ kelionės plane – čia matysite, kiek sutaupėte.',
  'histTrips': 'Kelionės', 'histHome': 'Šiais metais sutaupėte {v}',
  'finishTitle': 'Baigiau apsipirkti', 'finishOpen': 'Baigiau apsipirkti',
  'finishNone': 'Sąraše dar nepažymėjote nupirktų prekių.', 'finishMarkAll': 'Viską nupirkau',
  'finishSub': 'Nupirkta prekių: {n}. Jos bus išsaugotos istorijoje ir pašalintos iš sąrašo.',
  'finishReceipt': 'Kvito suma (nebūtina)', 'finishSpent': 'Išleista', 'finishSaving': 'Sutaupyta prekėms',
  'finishTravel': 'Kelionės degalai', 'finishNet': 'Iš viso', 'finishSave': 'Išsaugoti kelionę',
  'finishNoLt': 'Nežinome šių prekių kainų Lietuvoje, todėl sutaupymo apskaičiuoti negalime.',

  // Reference prices
  'unitPiece': 'vnt.', 'refUse': 'Įrašyti',
  'refPl': 'Įprasta kaina Lenkijoje ~{v}/{u} ({src}, pvz. {ex} – {p})',
  'refLt': 'Lietuvoje įprastai ~{v}/{u} ({src})',
  'refLtPack': 'Lietuvoje įprastai ~{v}/{u} ({src}) – tokiam kiekiui ≈ {p}',
  'refUsualPl': 'įprasta kaina ({src})', 'planVsLt': 'Lietuvoje {lt} – sutaupysite {v}', 'planVsLtWorse': 'Lietuvoje {lt} – ten pigiau {v}',

};

const _en = <String, String>{
  'tagline': 'Shop smarter in Poland.',
  'next': 'Next', 'back': 'Back', 'save': 'Save', 'cancel': 'Cancel', 'delete': 'Delete',
  'done': 'Done', 'add': 'Add', 'close': 'Close', 'retry': 'Try again', 'edit': 'Edit', 'undo': 'Undo',

  'tabHome': 'Home', 'tabList': 'List', 'tabTrip': 'Trip', 'tabMore': 'More',

  'helloMorning': 'Good morning', 'helloDay': 'Good afternoon', 'helloEvening': 'Good evening',
  'today': 'Today in Poland',
  'rateTitle': 'Euro rate', 'rateSource': 'NBP, {date}', 'rateLoading': 'Getting the rate…',
  'rateStale': 'Showing the last known rate', 'rateNone': 'No rate yet. Connect to the internet.',
  'shopsOpen': 'Today is a trading day', 'shopsSunday': 'Sunday: shops are closed', 'shopsHoliday': 'Holiday: shops are closed',
  'shopsTradingSunday': 'Trading Sunday: shops are open', 'shopsNext': 'Next Saturday {date}',
  'shopsNextClosed': 'Note: shops are closed on {date}',
  'timeThere': 'In Poland it’s {time}', 'timeThereSub': 'One hour behind Lithuania',
  'actionList': 'Shopping list', 'actionTrip': 'Is the trip worth it?', 'actionTripSub': 'We’ll work it out',
  'actionScan': 'Scan a product', 'actionScanSub': 'Find out what it is', 'actionConvert': 'Złoty to euro', 'actionConvertSub': 'What does it cost?',
  'tipTitle': 'Useful tip',
  'tipPay': 'When paying by card, always choose złoty (PLN), not euro. Otherwise your bank may use a 3–7% worse rate.',
  'tipDeposit': 'Plastic bottles and cans in Poland carry a 0.50 zł deposit. You only get it back by returning them in Poland.',
  'tipTime': 'Poland is one hour behind. A shop open until 21:00 closes at 22:00 Lithuanian time.',

  'listTitle': 'Shopping list', 'listEmpty': 'Your list is empty',
  'listEmptySub': 'Write down what you want to buy in Poland. We’ll show the Polish name so it’s easy to find in the shop.',
  'listAdd': 'Add item', 'listScan': 'Scan',
  'listInPl': 'In Poland', 'listInLt': 'In Lithuania', 'listSave': 'You save',
  'matchCount': '{n} deals from {v}', 'matchPickTitle': 'This week’s deals: {name}',
  'matchPickSub': 'Pick the one you’ll buy — we’ll fill in the price.', 'matchNone': 'Add without a price',
  'itemNeedLt': 'Add the LT price', 'listPlOnly': 'In Poland this costs about',
  'listPlOnlySub': 'Prices from deals ({n}/{m}). Add what they cost in Lithuania and we’ll show how much you save.',
  'listMissing': 'Prices still missing: {n}', 'listNoPrices': 'Enter prices and we’ll work out how much you save.',
  'listClearChecked': 'Remove bought items', 'itemAddPrices': 'Enter prices',
  'itemPricePl': 'Price in Poland', 'itemPriceLt': 'Price in Lithuania', 'itemQty': 'Quantity',
  'itemSaving': 'You save {v}', 'itemCheaperLt': 'Cheaper in Lithuania by {v}', 'itemSame': 'About the same',
  'itemPlName': 'In Polish', 'itemShowStaff': 'Show to shop staff', 'itemDelete': 'Remove from list',
  'itemRemoved': '“{name}” removed', 'itemEach': 'each',
  'addTitle': 'What do you want to buy?', 'addHint': 'E.g. butter, coffee, nappies', 'addCustom': 'Add “{q}”',
  'addPopular': 'Popular buys in Poland', 'addNoPl': 'no Polish translation', 'addAdded': 'Added: {name}',
  'staffHint': 'Show this screen to a shop assistant', 'staffTranslation': 'In English: {name}',

  'tripTitle': 'Is the trip worth it?', 'tripStep': 'Step {i} of {n}',
  'tripFrom': 'Where are you travelling from?', 'tripTo': 'Which town are you going to?', 'tripCar': 'What car do you drive?',
  'tripPeople': 'How many people are going?', 'tripPeopleSub': 'We’ll split the trip cost between everyone.',
  'tripFuel': 'What does fuel cost?', 'tripFuelSub': 'We filled in the latest average prices. If a station shows a different one, just type yours.',
  'fuelAuto': 'National average · {src}, {date}', 'fuelAutoRegion': 'Average ({region}) · {src}, {date}', 'fuelAutoConverted': ' · converted at the NBP rate',
  'fuelUseAuto': 'Use the average: {v}', 'srcEuBulletin': 'EU Oil Bulletin',
  'fuelDiesel': 'Diesel', 'fuelPetrol': 'Petrol', 'fuelLpg': 'LPG',
  'consumption': 'Uses per 100 km', 'refuel': 'How many litres will you fill in Poland?', 'refuelNone': 'None',
  'fuelLt': 'In Lithuania, € per litre', 'fuelPl': 'In Poland, zł per litre',
  'srcLt': 'Lithuanian prices: degalukainos.ena.lt', 'srcPl': 'Polish prices: e-petrol.pl',
  'resultWorth': 'Yes, it’s worth it', 'resultMarginal': 'Small benefit', 'resultNot': 'No, not worth it',
  'resultWorthSub': 'You save more than the trip costs.',
  'resultMarginalSub': 'The trip barely pays off. Add items or share the ride.',
  'resultNotSub': 'The trip costs more than you save.',
  'resultNet': 'Your benefit', 'resultPerPerson': '{v} per person',
  'rowDistance': 'Round trip', 'rowFuelTrip': 'Fuel for the trip', 'rowShopping': 'Cheaper shopping',
  'rowRefuel': 'Cheaper tank fill', 'rowTotal': 'Total', 'rowShoppingNone': 'Enter prices in your list',
  'breakEven': 'The trip pays off if you buy goods in Poland that would cost more than {v} in Lithuania.',
  'resultEdit': 'Change details', 'resultMaps': 'Open map', 'resultToList': 'Add to list',
  'estimate': 'Approximate: road distance; fuel prices are weekly averages or the ones you typed.',
  'tripSunday': 'Polish shops are closed this Sunday. Go on Saturday.',

  'convTitle': 'Złoty to euro', 'convPln': 'Złoty', 'convEur': 'Euro', 'convFee': 'Card fee',
  'convFeeSub': 'E.g. Revolut 0% on weekdays, some banks 1–3%', 'convRate': '€1 = {r} zł · NBP, {d}',
  'convQuick': 'Quick check',

  'scanTitle': 'Scan a barcode', 'scanHint': 'Point the camera at the barcode on the pack',
  'scanLooking': 'Looking up the product…', 'scanUnknown': 'This product isn’t in the database yet',
  'scanUnknownSub': 'Code {code}. You can type the name yourself.', 'scanAdd': 'Add to list', 'scanAgain': 'Scan another',
  'scanSource': 'Data: Open Food Facts (ODbL)', 'scanNoCamera': 'The camera didn’t start. Allow camera access or enter the code.',
  'scanManual': 'Enter code', 'scanFind': 'Find', 'scanOffline': 'No connection. Try again later.', 'scanName': 'Name',

  'moreTitle': 'More', 'setLang': 'Language', 'setText': 'Text size', 'textNormal': 'Normal', 'textLarge': 'Large', 'textXL': 'Extra large',
  'setTheme': 'Appearance', 'themeDark': 'Dark', 'themeLight': 'Light', 'themeSystem': 'Same as phone',
  'setHome': 'Home town', 'setCar': 'Car', 'setFee': 'Card fee', 'setPreview': 'This is how text will look',
  'aboutData': 'Where does the data come from?', 'privacy': 'Privacy', 'aboutApp': 'About Zlotika',
  'aboutAppText': 'Zlotika is free, ad-free and needs no account. It is not affiliated with any retailer.',
  'privacyText': 'No account needed. Your list and settings stay on this phone. We never ask for your location — you choose your town. The camera is only used to read barcodes.',
  'dataNbp': 'Exchange rate — National Bank of Poland (NBP), updated on working days.',
  'dataOff': 'Products by barcode — Open Food Facts, ODbL licence.',
  'dataCalendar': 'Trading Sundays and holidays — Polish law, built into the app.',
  'dataDistance': 'Distances — approximate, along main roads.',
  'dataPrices': 'Fuel prices are official weekly averages (EU Oil Bulletin, e-petrol.pl). Polish prices come from this week’s deals, and usual prices from the Rossmann website. Usual Lithuanian prices come from Barbora.lt (Maxima’s online shop), updated daily, and are marked “≈”. You can always enter your own price. Shop locations: © OpenStreetMap contributors; opening hours from the chains’ websites (Lidl, Aldi, Rossmann, Pepco, Dino, Netto) or OpenStreetMap.',
  'resetAll': 'Delete all my data', 'resetQ': 'Delete everything?', 'resetSub': 'Your list and settings on this phone will be deleted.',
  'version': 'Version {v}',

  'obWelcome': 'Welcome!', 'obWelcomeSub': 'Zlotika helps you decide whether a shopping trip to Poland is worth it, and how much you save.',
  'obTextSub': 'Choose a comfortable text size. You can change it any time.',
  'obHome': 'Which town do you travel from?', 'obHomeSub': 'We use it to work out the trip cost.', 'obStart': 'Start',

  'tabDeals': 'Deals', 'dealsTitle': 'This week’s deals', 'dealsUpdated': 'From retailer websites · updated {ago}',
  'agoNow': 'just now', 'agoH': '{n} h ago', 'agoD': '{n} d ago',
  'dealsSearch': 'Search deals', 'dealsAll': 'All', 'dealsTabDeals': 'Deals', 'dealsTabLeaflets': 'Leaflets',
  'dealsEmpty': 'No deals yet', 'dealsEmptySub': 'We update deals daily. Meanwhile, browse the official retailer leaflets.',
  'dealsShowLeaflets': 'Show leaflets', 'dealsNone': 'Nothing found', 'dealsLoading': 'Loading deals…',
  'dealsCard': 'With {card}', 'dealsCardGeneric': 'Card or app needed', 'dealsMinQty': 'When buying {n}+', 'dealsLimit': 'Max {n} per customer',
  'dealsUntil': 'until {date}', 'dealsFix': 'Your correction', 'dealsTranslated': 'In English',
  'dealAdd': 'Add to list', 'dealFixTitle': 'Different price in store?', 'dealFixHint': 'Enter the price you see. It will be used in your calculations.',
  'dealFixSave': 'Save price', 'dealFixClear': 'Restore original price', 'dealOpen': 'Open retailer page',
  'dealSource': 'Price taken from the {chain} website. It may differ in store.', 'dealPerUnit': '{v} per {unit}',
  'leafletsTitle': 'Official retailer leaflets', 'leafletsSub': 'Opens on the retailer’s website.', 'leafletOpen': 'Open leaflet',
  'homeDeals': 'This week’s deals', 'homeDealsSub': '{n} deals from Polish shops',

  'lfPages': '{n} pages', 'lfUntil': 'valid until {date}', 'lfOpenWeb': 'Open on website', 'lfOther': 'Other retailers’ leaflets',
  'lfOtherSub': 'These open on the retailer’s website.', 'lfPage': '{i} of {n}', 'lfNone': 'No leaflets yet',
  'lfLoading': 'Loading page…', 'lfError': 'Couldn’t load this page', 'lfHint': 'Pinch with two fingers to zoom',
  'dealOcr': 'From leaflet', 'dealOcrNote': 'Name and price were read automatically from the leaflet. Check the page before buying.',
  'dealSeePage': 'See leaflet page',
  // Trip plan
  'planTitle': 'Trip plan', 'planHome': 'Plan your trip', 'planHomeSub': 'Shops, opening hours, prices and route',
  'planToday': 'Today', 'planTomorrow': 'Tomorrow', 'planClosedShort': 'closed',
  'planDaySunday': 'That day is a Sunday: shops in Poland are closed (only fuel stations open). Pick another day.',
  'planDayHoliday': 'That day is a public holiday in Poland: shops are closed. Pick another day.',
  'planDrive': '{km} km each way, about {h} h of driving',
  'planHours': 'All your shops are open from {from} to {to}',
  'planLeaveBy': 'Leave by {t} Lithuanian time to make it to every shop',
  'planLate': 'Too late today to reach every shop (you needed to leave by {t}). Pick tomorrow.',
  'planTz': 'Poland is one hour behind. Lithuanian time is shown alongside.',
  'planSpend': 'You’ll spend in Poland about', 'planGuessed': '{n} of them at last time’s price',
  'planUnknown': 'Price not known yet: {n}', 'planNet': 'Trip benefit {v} · details',
  'planEmpty': 'First add what you want to buy.',
  'planStops': 'Stops ({n})', 'planLoose': 'No shop chosen yet',
  'planLooseSub': 'Tap an item and pick a deal or a shop to add it to the route.',
  'planRoute': 'Route through all shops', 'planChecklist': 'Before you go: checklist',
  'planOsm': 'Shop locations and hours: © OpenStreetMap contributors ({date}). Hours can change; check when it matters.',
  'planFuel': 'Fuel', 'planFuelLitres': 'Fill about {l} l',
  'planNoShop': 'We don’t know a shop of this chain in {town}', 'planNoAddress': 'Address unknown',
  'planOtherShop': 'Other shop', 'planSubtotal': 'At this shop', 'planNoPrice': 'price ?', 'planLastTime': 'last time ({d})',
  'hoursClosed': 'Closed that day', 'hours247': 'Open 24 hours', 'hoursUnknown': 'Hours unknown', 'hoursClosedNow': 'Closed for today',
  'hoursOpenUntil': 'Open now until {t} (LT {lt})', 'hoursOpensAt': 'Open {t}–{c} (LT {lt}–{lc})',
  'hoursGuessed': 'Usual hours for this chain in town; this shop’s exact hours are unknown.',
  'itemWhere': 'Where will you buy it?', 'itemWhereAny': 'Not sure yet',

  // Checklist
  'ckTitle': 'Before you go', 'ckProgress': '{n} of {m} checked',
  'ckDocs': 'Documents', 'ckRoad': 'Driving in Poland', 'ckShop': 'Shopping', 'ckSafety': 'Safety',
  'ckId': 'ID card or passport', 'ckIdSub': 'You must carry an ID document in Poland. There may be checks at the border.',
  'ckLicence': 'Driving licence and car documents', 'ckLicenceSub': 'Check your MOT and compulsory insurance are valid.',
  'ckLights': 'Dipped headlights all day', 'ckLightsSub': 'Required in Poland in daytime too.',
  'ckAlcohol': 'Alcohol limit 0.2‰', 'ckAlcoholSub': 'Stricter than in Lithuania. Safest is not to drink at all.',
  'ckSpeed': 'Speed: 50 / 90 / 120 / 140 km/h', 'ckSpeedSub': 'Towns 50, outside towns 90, expressways (S) up to 120, motorways 140. Many speed cameras.',
  'ckBags': 'Shopping bags', 'ckBagsSub': 'Bags cost extra in shops.',
  'ckCard': 'Pay in złoty', 'ckCardSub': 'At the card terminal choose PLN, not EUR, or the rate is 3–7% worse.',
  'ckDeposit': 'Deposit bottles', 'ckDepositSub': 'Bottles and cans carry a deposit in Poland. You only get it back by returning them in Poland.',
  'ckLimits': 'How much you can bring back', 'ckLimitsSub': 'EU guide levels for personal use: 800 cigarettes, 1 kg tobacco, 10 l spirits, 20 l intermediate products, 90 l wine (up to 60 l sparkling), 110 l beer. Fuel: in the tank plus up to 10 l in a can. More may be treated as trade by customs.',
  'ckLimitsLink': 'Customs information', 'ck112': 'Emergency number 112', 'ck112Sub': 'Works in Poland too. Below is a card in Polish if you need help.',
  'ckNote': 'General information, not legal advice. Rules can change.',
  'sosOpen': 'SOS card in Polish', 'sosCall': 'Call 112',
  'sosTranslation': 'In English: “I need help. Please call 112. I’m from Lithuania and don’t speak Polish.”',

  // Watchlist
  'watchTitle': 'Watchlist', 'watchHome': 'Watchlist', 'watchHomeSub': 'We’ll tell you when it’s on promotion',
  'watchHomeHits': 'Deals this week: {n}',
  'watchSub': 'Add what you buy regularly. When it goes on promotion in a Polish shop, we’ll let you know.',
  'watchAlerts': 'Notify me about new deals', 'watchAlertsSub': 'Your phone checks a few times a day. Nothing is sent to a server.',
  'watchNoPermission': 'Notifications are not allowed. Turn them on in your phone’s settings.',
  'watchHint': 'E.g. coffee, Pampers, Jacobs', 'watchCustom': 'Watch “{q}”', 'watchCustomSub': 'We’ll look for these words in deal names (brands work too)',
  'watchEmpty': 'You’re not watching anything yet.', 'watchNoDeals': 'No deals right now', 'watchAdd': 'Watch for deals', 'watchAdded': 'Watching: {name}',
  'alertOne': 'Deal on something you watch', 'alertMany': 'Deals on things you watch: {n}',

  // History
  'histTitle': 'Savings', 'histYear': 'Saved in {y}', 'histYearSub': 'Trips: {n} · spent in Poland {v}',
  'histHow': 'Only items with a known Lithuanian price count, minus fuel for the drive.',
  'histEmpty': 'When you’re back from Poland, tap “Done shopping” in the trip plan and your savings will show here.',
  'histTrips': 'Trips', 'histHome': 'Saved this year: {v}',
  'finishTitle': 'Done shopping', 'finishOpen': 'Done shopping',
  'finishNone': 'You haven’t ticked any items as bought yet.', 'finishMarkAll': 'I bought everything',
  'finishSub': 'Items bought: {n}. They’ll be saved in your history and removed from the list.',
  'finishReceipt': 'Receipt total (optional)', 'finishSpent': 'Spent', 'finishSaving': 'Saved on items',
  'finishTravel': 'Fuel for the drive', 'finishNet': 'Total', 'finishSave': 'Save trip',
  'finishNoLt': 'We don’t know these items’ Lithuanian prices, so we can’t work out the saving.',

  // Reference prices
  'unitPiece': 'pc', 'refUse': 'Use',
  'refPl': 'Usual price in Poland ~{v}/{u} ({src}, e.g. {ex} – {p})',
  'refLt': 'Usually in Lithuania ~{v}/{u} ({src})',
  'refLtPack': 'Usually in Lithuania ~{v}/{u} ({src}) – for this amount ≈ {p}',
  'refUsualPl': 'usual price ({src})', 'planVsLt': 'In Lithuania {lt} – you save {v}', 'planVsLtWorse': 'In Lithuania {lt} – cheaper there by {v}',

};

/// Translation without a BuildContext (notifications, background work).
String tr(Lang lang, String key, [Map<String, Object> vars = const {}]) {
  var v = (lang == Lang.lt ? _lt : _en)[key] ?? _lt[key] ?? key;
  vars.forEach((k, val) => v = v.replaceAll('{$k}', '$val'));
  return v;
}

extension I18n on BuildContext {
  Lang get lang => AppScope.of(this).lang;

  String s(String key, [Map<String, Object> vars = const {}]) {
    final dict = lang == Lang.lt ? _lt : _en;
    var v = dict[key] ?? _lt[key] ?? key;
    vars.forEach((k, val) => v = v.replaceAll('{$k}', '$val'));
    return v;
  }

  /// Lithuanian has three count forms: 1 prekė, 2 prekės, 10 prekių.
  String items(int n) {
    if (lang == Lang.en) return n == 1 ? '1 item' : '$n items';
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return '$n prekė';
    if (m10 >= 2 && m10 <= 9 && (m100 < 11 || m100 > 19)) return '$n prekės';
    return '$n prekių';
  }
}
