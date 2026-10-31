/// Italian labels for common OpenStreetMap place categories.
///
/// Both Photon (`osm_value`) and OpenMapTiles POIs (`class` / `subclass`)
/// expose OSM tag values. Unknown values return null: Navia shows no category
/// rather than an invented or untranslated one.
abstract final class PlaceCategory {
  static String? label(String? value) =>
      value == null ? null : _labels[value.toLowerCase()];

  /// The first known label among [values], most specific first.
  static String? firstLabel(Iterable<String?> values) {
    for (final value in values) {
      final label = PlaceCategory.label(value);
      if (label != null) return label;
    }
    return null;
  }

  static const _labels = {
    // Food and drink.
    'restaurant': 'Ristorante',
    'fast_food': 'Fast food',
    'cafe': 'Caffè',
    'bar': 'Bar',
    'pub': 'Pub',
    'ice_cream': 'Gelateria',
    'bakery': 'Panetteria',
    'pastry': 'Pasticceria',
    'beer': 'Birreria',
    // Shops.
    'supermarket': 'Supermercato',
    'grocery': 'Alimentari',
    'convenience': 'Minimarket',
    'shop': 'Negozio',
    'clothes': 'Abbigliamento',
    'clothing_store': 'Abbigliamento',
    'butcher': 'Macelleria',
    'books': 'Libreria',
    'mall': 'Centro commerciale',
    'marketplace': 'Mercato',
    // Health.
    'pharmacy': 'Farmacia',
    'hospital': 'Ospedale',
    'clinic': 'Clinica',
    'doctors': 'Studio medico',
    'dentist': 'Dentista',
    // Services.
    'bank': 'Banca',
    'atm': 'Bancomat',
    'post_office': 'Ufficio postale',
    'post': 'Ufficio postale',
    'police': 'Polizia',
    'fire_station': 'Vigili del fuoco',
    'townhall': 'Municipio',
    'town_hall': 'Municipio',
    'fuel': 'Distributore di carburante',
    'charging_station': 'Ricarica veicoli elettrici',
    'parking': 'Parcheggio',
    'bicycle_parking': 'Parcheggio bici',
    'toilets': 'Bagni pubblici',
    'drinking_water': 'Fontanella',
    'library': 'Biblioteca',
    // Education.
    'school': 'Scuola',
    'kindergarten': 'Scuola dell’infanzia',
    'college': 'Istituto superiore',
    'university': 'Università',
    // Culture and leisure.
    'gallery': 'Galleria d’arte',
    'museum': 'Museo',
    'theatre': 'Teatro',
    'cinema': 'Cinema',
    'attraction': 'Attrazione',
    'artwork': 'Opera d’arte',
    'monument': 'Monumento',
    'memorial': 'Memoriale',
    'castle': 'Castello',
    'place_of_worship': 'Luogo di culto',
    'church': 'Chiesa',
    'cathedral': 'Cattedrale',
    'park': 'Parco',
    'garden': 'Giardino',
    'playground': 'Parco giochi',
    'stadium': 'Stadio',
    'sports_centre': 'Centro sportivo',
    'swimming_pool': 'Piscina',
    'beach': 'Spiaggia',
    'beach_resort': 'Lido',
    'viewpoint': 'Punto panoramico',
    // Lodging.
    'hotel': 'Hotel',
    'lodging': 'Alloggio',
    'motel': 'Motel',
    'hostel': 'Ostello',
    'guest_house': 'Pensione',
    // Transport.
    'bus': 'Fermata autobus',
    'bus_station': 'Autostazione',
    'tram_stop': 'Fermata del tram',
    'halt': 'Fermata ferroviaria',
    'bus_stop': 'Fermata autobus',
    'railway': 'Stazione ferroviaria',
    'station': 'Stazione',
    'ferry_terminal': 'Terminal traghetti',
    'harbor': 'Porto',
    'aerodrome': 'Aeroporto',
    'airport': 'Aeroporto',
    // Geographic types (Photon `type`).
    'house': 'Indirizzo',
    'street': 'Strada',
    'city': 'Città',
    'town': 'Comune',
    'village': 'Paese',
    'district': 'Quartiere',
    'suburb': 'Quartiere',
    'locality': 'Località',
  };
}
