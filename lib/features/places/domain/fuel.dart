import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

/// A price reported to the Ministry by a fuel station.
@immutable
class FuelPrice {
  const FuelPrice({
    required this.fuel,
    required this.price,
    required this.selfService,
    required this.reportedAt,
  });

  /// Fuel name as published, e.g. "Benzina", "Gasolio", "GPL".
  final String fuel;

  /// Euro per liter (per kilogram for methane).
  final double price;

  final bool selfService;

  /// When the operator reported this price.
  final DateTime reportedAt;
}

/// A fuel station from the MIMIT registry, with its current prices.
@immutable
class FuelStation {
  const FuelStation({
    required this.id,
    required this.point,
    required this.brand,
    required this.name,
    required this.address,
    required this.town,
    required this.prices,
  });

  final int id;
  final GeoPoint point;
  final String brand;
  final String name;
  final String address;
  final String town;
  final List<FuelPrice> prices;

  /// Parses one dataset entry: [id, lat, lon, brand, name, address, town,
  /// [[fuel, price, self, "YYYY-MM-DDTHH:MM"], ...]].
  static FuelStation? tryParse(Object? entry) {
    if (entry is! List || entry.length < 8) return null;
    final [id, lat, lon, brand, name, address, town, prices, ...] = entry;
    final point = GeoPoint.tryCreate(
      lat is num ? lat : null,
      lon is num ? lon : null,
    );
    if (id is! int || point == null || prices is! List) return null;
    final parsed = <FuelPrice>[
      for (final price in prices)
        if (price case [
          final String fuel,
          final num value,
          final bool self,
          final String reported,
        ])
          if (DateTime.tryParse(reported) case final reportedAt?)
            FuelPrice(
              fuel: fuel,
              price: value.toDouble(),
              selfService: self,
              reportedAt: reportedAt,
            ),
    ];
    if (parsed.isEmpty) return null;
    return FuelStation(
      id: id,
      point: point,
      brand: brand is String ? brand : '',
      name: name is String ? name : '',
      address: address is String ? address : '',
      town: town is String ? town : '',
      prices: parsed,
    );
  }
}
