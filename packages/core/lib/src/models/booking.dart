import 'json_value.dart';
import 'route.dart';

enum BookingType { ride, goods }

enum BookingStatus {
  created,
  priced,
  searching,
  assigned,
  driverArriving,
  inProgress,
  completed,
  cancelled,
  failed;

  String get apiValue => switch (this) {
        BookingStatus.created => 'CREATED',
        BookingStatus.priced => 'PRICED',
        BookingStatus.searching => 'SEARCHING',
        BookingStatus.assigned => 'ASSIGNED',
        BookingStatus.driverArriving => 'DRIVER_ARRIVING',
        BookingStatus.inProgress => 'IN_PROGRESS',
        BookingStatus.completed => 'COMPLETED',
        BookingStatus.cancelled => 'CANCELLED',
        BookingStatus.failed => 'FAILED',
      };

  static BookingStatus fromApi(String value) => values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => BookingStatus.created,
      );
}

enum PaymentMethod { cash, upi, card, wallet }

enum PaymentState { unpaid, paid, refunded, failed }

class DriverInfo {
  const DriverInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.ratingAvg,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String phone;
  final double ratingAvg;
  final String? photoUrl;

  factory DriverInfo.fromJson(Map<String, dynamic> json) => DriverInfo(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        ratingAvg: jsonDouble(json['rating_avg']) ?? 0,
        photoUrl: json['photo_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'rating_avg': ratingAvg,
        'photo_url': photoUrl,
      };
}

class VehicleInfo {
  const VehicleInfo({
    required this.registrationNumber,
    required this.make,
    required this.color,
    required this.category,
  });

  final String registrationNumber;
  final String make;
  final String color;
  final String category;

  factory VehicleInfo.fromJson(Map<String, dynamic> json) => VehicleInfo(
        registrationNumber: json['registration_number'] as String? ?? '',
        make: json['make'] as String? ?? '',
        color: json['color'] as String? ?? '',
        category: json['category'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'registration_number': registrationNumber,
        'make': make,
        'color': color,
        'category': category,
      };
}

class Booking {
  const Booking({
    required this.id,
    required this.type,
    required this.status,
    required this.serviceCategoryCode,
    required this.serviceCategoryName,
    required this.pickupAddress,
    required this.dropAddress,
    required this.quotedFarePaise,
    this.finalFarePaise,
    required this.paymentMethod,
    required this.paymentState,
    this.scheduledAt,
    required this.createdAt,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.driver,
    this.vehicle,
    this.otp,
    this.goodsType,
    this.weightKg,
    this.dimensionsCuft,
    this.needsLoadingHelp = false,
    this.senderName,
    this.senderPhone,
    this.receiverName,
    this.receiverPhone,
    this.route,
  });

  final String id;
  final BookingType type;
  final BookingStatus status;
  final String serviceCategoryCode;
  final String serviceCategoryName;
  final String pickupAddress;
  final String dropAddress;
  final int quotedFarePaise;
  final int? finalFarePaise;
  final PaymentMethod paymentMethod;
  final PaymentState paymentState;
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final DriverInfo? driver;
  final VehicleInfo? vehicle;
  final String? otp;

  // Goods-only (Milestone E).
  final String? goodsType;
  final int? weightKg;
  final double? dimensionsCuft;
  final bool needsLoadingHelp;
  final String? senderName;
  final String? senderPhone;
  final String? receiverName;
  final String? receiverPhone;
  final RouteInfo? route;

  bool get isGoods => type == BookingType.goods;
  int get finalFare => finalFarePaise ?? quotedFarePaise;

  Booking copyWith({
    BookingStatus? status,
    int? finalFarePaise,
    PaymentState? paymentState,
    PaymentMethod? paymentMethod,
    DriverInfo? driver,
    VehicleInfo? vehicle,
    String? otp,
    RouteInfo? route,
  }) {
    return Booking(
      id: id,
      type: type,
      status: status ?? this.status,
      serviceCategoryCode: serviceCategoryCode,
      serviceCategoryName: serviceCategoryName,
      pickupAddress: pickupAddress,
      dropAddress: dropAddress,
      quotedFarePaise: quotedFarePaise,
      finalFarePaise: finalFarePaise ?? this.finalFarePaise,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentState: paymentState ?? this.paymentState,
      scheduledAt: scheduledAt,
      createdAt: createdAt,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropLat: dropLat,
      dropLng: dropLng,
      driver: driver ?? this.driver,
      vehicle: vehicle ?? this.vehicle,
      otp: otp ?? this.otp,
      goodsType: goodsType,
      weightKg: weightKg,
      dimensionsCuft: dimensionsCuft,
      needsLoadingHelp: needsLoadingHelp,
      senderName: senderName,
      senderPhone: senderPhone,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      route: route ?? this.route,
    );
  }

  /// Parses both the real API shape (nested `service_category`, `pickup`,
  /// `drop`, `fare`) and the flat mock shape used by the offline adapter.
  factory Booking.fromJson(Map<String, dynamic> json) {
    final category = json['service_category'];
    final pickup = json['pickup'];
    final drop = json['drop'];
    final fare = json['fare'];
    final trip = json['trip'];
    final shipment = json['shipment'];
    final categoryMap = category is Map<String, dynamic> ? category : null;
    final pickupMap = pickup is Map<String, dynamic> ? pickup : null;
    final dropMap = drop is Map<String, dynamic> ? drop : null;
    final fareMap = fare is Map<String, dynamic> ? fare : null;
    final tripMap = trip is Map<String, dynamic> ? trip : null;
    final shipmentMap = shipment is Map<String, dynamic> ? shipment : null;
    final categoryCode = categoryMap?['code'] as String? ??
        (category is String ? category : null) ??
        json['service_category_code'] as String? ??
        '';
    final categoryName = categoryMap?['name'] as String? ??
        json['service_category_name'] as String? ??
        categoryCode;
    final otp = json['otp'] as String? ??
        (shipmentMap?['delivery_otp'] as String?) ??
        (tripMap?['start_otp'] as String?);

    return Booking(
      id: json['id'] as String,
      type: (json['type'] as String) == 'goods'
          ? BookingType.goods
          : BookingType.ride,
      status: BookingStatus.fromApi(json['status'] as String? ?? 'CREATED'),
      serviceCategoryCode: categoryCode,
      serviceCategoryName: categoryName,
      pickupAddress: (pickupMap?['address'] as String?) ??
          json['pickup_address'] as String? ??
          '',
      dropAddress: (dropMap?['address'] as String?) ??
          json['drop_address'] as String? ??
          '',
      quotedFarePaise: (fareMap?['quoted_paise'] as num?)?.toInt() ??
          (json['quoted_fare_paise'] as num?)?.toInt() ??
          0,
      finalFarePaise: (fareMap?['final_paise'] as num?)?.toInt() ??
          (json['final_fare_paise'] as num?)?.toInt(),
      paymentMethod:
          PaymentMethod.values.asNameMap()[json['payment_method'] as String?] ??
              PaymentMethod.cash,
      paymentState:
          PaymentState.values.asNameMap()[json['payment_state'] as String?] ??
              PaymentState.unpaid,
      scheduledAt: json['scheduled_at'] == null
          ? null
          : DateTime.tryParse(json['scheduled_at'] as String),
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
      pickupLat: (pickupMap?['lat'] as num?)?.toDouble() ??
          (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (pickupMap?['lng'] as num?)?.toDouble() ??
          (json['pickup_lng'] as num?)?.toDouble(),
      dropLat: (dropMap?['lat'] as num?)?.toDouble() ??
          (json['drop_lat'] as num?)?.toDouble(),
      dropLng: (dropMap?['lng'] as num?)?.toDouble() ??
          (json['drop_lng'] as num?)?.toDouble(),
      driver: json['driver'] == null
          ? null
          : DriverInfo.fromJson(json['driver'] as Map<String, dynamic>),
      vehicle: json['vehicle'] == null
          ? null
          : VehicleInfo.fromJson(json['vehicle'] as Map<String, dynamic>),
      otp: otp,
      goodsType: (shipmentMap?['goods_type'] as String?) ??
          json['goods_type'] as String?,
      weightKg: (shipmentMap?['weight_kg'] as num?)?.toInt() ??
          (json['weight_kg'] as num?)?.toInt(),
      dimensionsCuft: (shipmentMap?['dimensions_cuft'] as num?)?.toDouble() ??
          jsonDouble(json['dimensions_cuft']),
      needsLoadingHelp: (shipmentMap?['needs_loading_help'] as bool?) ??
          (json['needs_loading_help'] as bool?) ??
          false,
      senderName: (shipmentMap?['sender_name'] as String?) ??
          json['sender_name'] as String?,
      senderPhone: (shipmentMap?['sender_phone'] as String?) ??
          json['sender_phone'] as String?,
      receiverName: (shipmentMap?['receiver_name'] as String?) ??
          json['receiver_name'] as String?,
      receiverPhone: (shipmentMap?['receiver_phone'] as String?) ??
          json['receiver_phone'] as String?,
      route: json['route'] == null
          ? null
          : RouteInfo.fromJson(json['route'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == BookingType.goods ? 'goods' : 'ride',
        'status': status.apiValue,
        'service_category_code': serviceCategoryCode,
        'service_category_name': serviceCategoryName,
        'service_category': {
          'code': serviceCategoryCode,
          'name': serviceCategoryName,
        },
        'pickup_address': pickupAddress,
        'drop_address': dropAddress,
        'pickup': {'lat': pickupLat, 'lng': pickupLng, 'address': pickupAddress},
        'drop': {'lat': dropLat, 'lng': dropLng, 'address': dropAddress},
        'quoted_fare_paise': quotedFarePaise,
        'final_fare_paise': finalFarePaise,
        'fare': {
          'quoted_paise': quotedFarePaise,
          'final_paise': finalFarePaise,
        },
        'payment_method': paymentMethod.name,
        'payment_state': paymentState.name,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'drop_lat': dropLat,
        'drop_lng': dropLng,
        'driver': driver?.toJson(),
        'vehicle': vehicle?.toJson(),
        'otp': otp,
        'goods_type': goodsType,
        'weight_kg': weightKg,
        'dimensions_cuft': dimensionsCuft,
        'needs_loading_help': needsLoadingHelp,
        'sender_name': senderName,
        'sender_phone': senderPhone,
        'receiver_name': receiverName,
        'receiver_phone': receiverPhone,
        'route': route?.toJson(),
      };
}
