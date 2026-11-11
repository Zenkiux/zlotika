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
  'dataPrices': 'Degalų kainos – oficialūs savaitės vidurkiai (ES naftos biuletenis, e-petrol.pl). Lenkiškų prekių kainos imamos iš šios savaitės akcijų. Lietuviškas kainas kol kas įrašote jūs.',
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
  'dataPrices': 'Fuel prices are official weekly averages (EU Oil Bulletin, e-petrol.pl). Polish product prices come from this week’s deals. Lithuanian prices you still enter yourself for now.',
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
};

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
