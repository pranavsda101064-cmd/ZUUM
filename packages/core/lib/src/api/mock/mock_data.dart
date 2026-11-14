import 'dart:math';

import '../../models/models.dart';

/// Fabricated Bengaluru development data for `ENV=mock`.
/// NOT real data — development only.
class MockData {
  MockData._();

  static const serviceCategories = <ServiceCategory>[
    // passenger mobility
    ServiceCategory(code: 'bike', kind: ServiceKind.ride, name: 'Bike', seats: 1,
        description: 'Quick hops across the city'),
    ServiceCategory(code: 'auto', kind: ServiceKind.ride, name: 'Auto', seats: 3,
        description: 'Auto rickshaw, metered fares'),
    ServiceCategory(code: 'hatchback', kind: ServiceKind.ride, name: 'Hatchback', seats: 4),
    ServiceCategory(code: 'sedan', kind: ServiceKind.ride, name: 'Sedan', seats: 4),
    ServiceCategory(code: 'suv', kind: ServiceKind.ride, name: 'SUV', seats: 6),
    ServiceCategory(code: 'premium', kind: ServiceKind.ride, name: 'Premium', seats: 4,
        description: 'Executive cars'),
    // goods transportation
    ServiceCategory(code: 'goods_2w', kind: ServiceKind.goods, name: '2W Goods',
        capacityKg: 20, volumeCuft: 6, description: 'Two-wheeler delivery'),
    ServiceCategory(code: 'goods_3w', kind: ServiceKind.goods, name: '3W Cargo',
        capacityKg: 300, volumeCuft: 40, description: 'Three-wheeler cargo'),
    ServiceCategory(code: 'ace', kind: ServiceKind.goods, name: 'Tata Ace',
        capacityKg: 750, volumeCuft: 120, description: 'Mini truck'),
    ServiceCategory(code: 'pickup', kind: ServiceKind.goods, name: 'Pickup',
        capacityKg: 1000, volumeCuft: 180),
    ServiceCategory(code: 'van', kind: ServiceKind.goods, name: 'Van',
        capacityKg: 1200, volumeCuft: 220),
    ServiceCategory(code: 'tempo', kind: ServiceKind.goods, name: 'Tempo',
        capacityKg: 2500, volumeCuft: 350),
  ];

  static const rates = <String, _Rate>{    'bike': _Rate(basePaise: 3000, perKmPaise: 700, perMinPaise: 90),
    'auto': _Rate(basePaise: 3000, perKmPaise: 850, perMinPaise: 100),
    'hatchback': _Rate(basePaise: 6000, perKmPaise: 1200, perMinPaise: 150),
    'sedan': _Rate(basePaise: 8000, perKmPaise: 1400, perMinPaise: 170),
    'suv': _Rate(basePaise: 12000, perKmPaise: 1800, perMinPaise: 210),
    'premium': _Rate(basePaise: 20000, perKmPaise: 2500, perMinPaise: 300),
    'goods_2w': _Rate(basePaise: 4000, perKmPaise: 900, perMinPaise: 110),
    'goods_3w': _Rate(basePaise: 6000, perKmPaise: 1100, perMinPaise: 130),
    'ace': _Rate(basePaise: 8000, perKmPaise: 1400, perMinPaise: 170),
    'pickup': _Rate(basePaise: 10000, perKmPaise: 1600, perMinPaise: 190),
    'van': _Rate(basePaise: 12000, perKmPaise: 1800, perMinPaise: 210),
    'tempo': _Rate(basePaise: 15000, perKmPaise: 2100, perMinPaise: 250),
  };

  static List<SavedAddress> defaultAddresses(String userId) => [
        SavedAddress(
          id: '$userId-home',
          label: 'home',
          name: 'Home',
          lat: 12.9352,
          lng: 77.6245,
          address: '42, 7th Cross, Jayanagar 3rd Block, Bengaluru 560011',
          isDefault: true,
        ),
        SavedAddress(
          id: '$userId-work',
          label: 'work',
          name: 'Work',
          lat: 12.9719,
          lng: 77.6412,
          address: 'Prestige Trade Tower, Palace Road, Bengaluru 560001',
        ),
      ];

  static List<Booking> seedBookings(String userId) => [
        Booking(
          id: '$userId-bk-1',
          type: BookingType.ride,
          status: BookingStatus.completed,
          serviceCategoryCode: 'auto',
          serviceCategoryName: 'Auto',
          pickupAddress: '42, 7th Cross, Jayanagar 3rd Block, Bengaluru',
          dropAddress: 'Phoenix Marketcity, Whitefield, Bengaluru',
          quotedFarePaise: 28600,
          finalFarePaise: 29800,
          paymentMethod: PaymentMethod.cash,
          paymentState: PaymentState.paid,
          createdAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
          driver: const DriverInfo(
            id: 'drv-1',
            name: 'Ravi Kumar',
            phone: '+919800000001',
            ratingAvg: 4.8,
          ),
          vehicle: const VehicleInfo(
            registrationNumber: 'KA 05 AB 1234',
            make: 'Piaggio Ape',
            color: 'Yellow',
            category: 'auto',
          ),
        ),
        Booking(
          id: '$userId-bk-2',
          type: BookingType.goods,
          status: BookingStatus.completed,
          serviceCategoryCode: 'ace',
          serviceCategoryName: 'Tata Ace',
          pickupAddress: 'Chickpete Main Road, Bengaluru',
          dropAddress: 'HSR Layout Sector 2, Bengaluru',
          quotedFarePaise: 145000,
          finalFarePaise: 152000,
          paymentMethod: PaymentMethod.upi,
          paymentState: PaymentState.paid,
          createdAt: DateTime.now().toUtc().subtract(const Duration(days: 6)),
        ),
      ];

  static const promos = <PromoCampaign>[
    PromoCampaign(
      code: 'ZUUM50',
      title: '50% off your next ride',
      description: 'Up to ₹50 off on any ride. Min fare ₹100.',
      type: PromoType.percent,
      value: 50,
      maxDiscountPaise: 5000,
      minFarePaise: 10000,
    ),
    PromoCampaign(
      code: 'NAMMA100',
      title: '₹100 off goods delivery',
      description: 'Flat ₹100 off on any goods booking. Min fare ₹300.',
      type: PromoType.flat,
      value: 10000,
      maxDiscountPaise: 10000,
      minFarePaise: 30000,
    ),
    PromoCampaign(
      code: 'BLR20',
      title: '20% off, up to ₹30',
      description: 'A little something for Namma Bengaluru.',
      type: PromoType.percent,
      value: 20,
      maxDiscountPaise: 3000,
      minFarePaise: 5000,
    ),
  ];

  static const supportTopics = <SupportTopic>[
    SupportTopic(
      id: 'lost-item',
      title: 'Lost item in a vehicle',
      body: 'Share your trip details and we will contact the driver within 24 hours.',
    ),
    SupportTopic(
      id: 'fare-issue',
      title: 'Fare or payment issue',
      body: 'For fare disputes, keep your trip receipt handy. Refunds settle in 3-5 days.',
    ),
    SupportTopic(
      id: 'driver-behaviour',
      title: 'Driver behaviour',
      body: 'Report unsafe driving or unprofessional conduct. We review every report.',
    ),
    SupportTopic(
      id: 'delivery-issue',
      title: 'Goods delivery issue',
      body: 'Damaged or delayed deliveries are covered by our proof-of-delivery records.',
    ),
  ];

  static List<ZNotification> seedNotifications(String Function(String) nextId) => [
        ZNotification(
          id: nextId('ntf'),
          title: 'Welcome to Zuum',
          body: 'Old Bengaluru soul. New Bengaluru movement. Book your first ride.',
          type: 'system',
          createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        ),
        ZNotification(
          id: nextId('ntf'),
          title: 'ZUUM50 is live',
          body: 'Get 50% off your next ride, up to ₹50.',
          type: 'promo',
          createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        ),
      ];

  /// Great-circle distance in metres (mock fare input).
  static double haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;
}

class _Rate {
  const _Rate({required this.basePaise, required this.perKmPaise, required this.perMinPaise});
  final int basePaise;
  final int perKmPaise;
  final int perMinPaise;
}
