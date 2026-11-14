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
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
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
    );
  }

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        type: (json['type'] as String) == 'goods' ? BookingType.goods : BookingType.ride,
        status: BookingStatus.fromApi(json['status'] as String? ?? 'CREATED'),
        serviceCategoryCode: json['service_category_code'] as String? ?? '',
        serviceCategoryName: json['service_category_name'] as String? ?? '',
        pickupAddress: json['pickup_address'] as String? ?? '',
        dropAddress: json['drop_address'] as String? ?? '',
        quotedFarePaise: (json['quoted_fare_paise'] as num?)?.toInt() ?? 0,
        finalFarePaise: (json['final_fare_paise'] as num?)?.toInt(),
        paymentMethod: PaymentMethod.values.asNameMap()[json['payment_method'] as String?] ??
            PaymentMethod.cash,
        paymentState: PaymentState.values.asNameMap()[json['payment_state'] as String?] ??
            PaymentState.unpaid,
        scheduledAt: json['scheduled_at'] == null
            ? null
            : DateTime.tryParse(json['scheduled_at'] as String),
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
        pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
        pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
        dropLat: (json['drop_lat'] as num?)?.toDouble(),
        dropLng: (json['drop_lng'] as num?)?.toDouble(),
        driver: json['driver'] == null
            ? null
            : DriverInfo.fromJson(json['driver'] as Map<String, dynamic>),
        vehicle: json['vehicle'] == null
            ? null
            : VehicleInfo.fromJson(json['vehicle'] as Map<String, dynamic>),
        otp: json['otp'] as String?,
        goodsType: json['goods_type'] as String?,
        weightKg: (json['weight_kg'] as num?)?.toInt(),
        dimensionsCuft: (json['dimensions_cuft'] as num?)?.toDouble(),
        needsLoadingHelp: json['needs_loading_help'] as bool? ?? false,
        senderName: json['sender_name'] as String?,
        senderPhone: json['sender_phone'] as String?,
        receiverName: json['receiver_name'] as String?,
        receiverPhone: json['receiver_phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == BookingType.goods ? 'goods' : 'ride',
        'status': status.apiValue,
        'service_category_code': serviceCategoryCode,
        'service_category_name': serviceCategoryName,
        'pickup_address': pickupAddress,
        'drop_address': dropAddress,
        'quoted_fare_paise': quotedFarePaise,
        'final_fare_paise': finalFarePaise,
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
      };
}
