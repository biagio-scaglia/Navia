/// Categories offered by place discovery, each mapped to the OpenStreetMap
/// tags that define it.
enum PoiCategory {
  restaurants('Ristoranti', {
    'amenity': ['restaurant', 'fast_food'],
  }),
  cafes('Bar e caffè', {
    'amenity': ['cafe', 'bar', 'pub', 'ice_cream'],
  }),
  supermarkets('Supermercati', {
    'shop': ['supermarket', 'convenience'],
  }),
  pharmacies('Farmacie', {
    'amenity': ['pharmacy'],
  }),
  hospitals('Ospedali', {
    'amenity': ['hospital', 'clinic'],
  }),
  museums('Musei', {
    'tourism': ['museum', 'gallery'],
  }),
  attractions('Attrazioni', {
    'tourism': ['attraction', 'viewpoint'],
  }),
  parks('Parchi', {
    'leisure': ['park', 'garden'],
  }),
  hotels('Hotel', {
    'tourism': ['hotel', 'guest_house', 'hostel', 'motel'],
  }),
  transport('Trasporti', {
    'highway': ['bus_stop'],
    'railway': ['station', 'halt', 'tram_stop'],
    'amenity': ['bus_station'],
  }),
  parking('Parcheggi', {
    'amenity': ['parking'],
  }),
  fuel('Carburante', {
    'amenity': ['fuel'],
  }),
  atms('Bancomat', {
    'amenity': ['atm'],
  }),
  drinkingWater('Fontanelle', {
    'amenity': ['drinking_water'],
  }),
  toilets('Bagni', {
    'amenity': ['toilets'],
  }),
  beaches('Spiagge', {
    'natural': ['beach'],
    'leisure': ['beach_resort'],
  });

  const PoiCategory(this.label, this.tags);

  /// Italian label shown on the filter chip.
  final String label;

  /// OpenStreetMap keys and the values that belong to this category.
  final Map<String, List<String>> tags;

  /// Whether an object with [objectTags] belongs to this category.
  bool matches(Map<String, String> objectTags) =>
      tags.entries.any((entry) => entry.value.contains(objectTags[entry.key]));
}
