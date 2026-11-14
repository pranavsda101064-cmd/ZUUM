import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

enum BookingMode { ride, goods }

/// Goods shipment details (Milestone E) — carried on the draft until the
/// booking is created.
@immutable
class GoodsDetails {
  const GoodsDetails({
    this.goodsType,
    this.weightKg,
    this.dimensionsCuft,
    this.needsLoadingHelp = false,
    this.senderName,
    this.senderPhone,
    this.receiverName,
    this.receiverPhone,
  });

  final String? goodsType;
  final int? weightKg;
  final double? dimensionsCuft;
  final bool needsLoadingHelp;
  final String? senderName;
  final String? senderPhone;
  final String? receiverName;
  final String? receiverPhone;

  bool get isComplete =>
      goodsType != null &&
      weightKg != null &&
      (receiverName?.isNotEmpty ?? false) &&
      (receiverPhone?.isNotEmpty ?? false);

  GoodsDetails copyWith({
    String? goodsType,
    int? weightKg,
    double? dimensionsCuft,
    bool? needsLoadingHelp,
    String? senderName,
    String? senderPhone,
    String? receiverName,
    String? receiverPhone,
  }) {
    return GoodsDetails(
      goodsType: goodsType ?? this.goodsType,
      weightKg: weightKg ?? this.weightKg,
      dimensionsCuft: dimensionsCuft ?? this.dimensionsCuft,
      needsLoadingHelp: needsLoadingHelp ?? this.needsLoadingHelp,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
    );
  }
}

/// In-progress booking selections flowing across the booking screens.
@immutable
class BookingDraft {
  const BookingDraft({
    this.mode = BookingMode.ride,
    this.pickup,
    this.drop,
    this.selectedCategoryCode,
    this.paymentMethod = PaymentMethod.cash,
    this.scheduledAt,
    this.goods,
    this.promoCode,
  });

  final BookingMode mode;
  final PlaceSuggestion? pickup;
  final PlaceSuggestion? drop;
  final String? selectedCategoryCode;
  final PaymentMethod paymentMethod;
  final DateTime? scheduledAt;
  final GoodsDetails? goods;
  final String? promoCode;

  bool get hasRoute => pickup != null && drop != null;

  LocationPoint? get pickupPoint => pickup == null
      ? null
      : LocationPoint(lat: pickup!.lat, lng: pickup!.lng, address: pickup!.address);
  LocationPoint? get dropPoint => drop == null
      ? null
      : LocationPoint(lat: drop!.lat, lng: drop!.lng, address: drop!.address);

  BookingDraft copyWith({
    BookingMode? mode,
    PlaceSuggestion? pickup,
    PlaceSuggestion? drop,
    bool clearDrop = false,
    String? selectedCategoryCode,
    PaymentMethod? paymentMethod,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    GoodsDetails? goods,
    String? promoCode,
    bool clearPromo = false,
  }) {
    return BookingDraft(
      mode: mode ?? this.mode,
      pickup: pickup ?? this.pickup,
      drop: clearDrop ? null : drop ?? this.drop,
      selectedCategoryCode: selectedCategoryCode ?? this.selectedCategoryCode,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
      goods: goods ?? this.goods,
      promoCode: clearPromo ? null : promoCode ?? this.promoCode,
    );
  }
}

class BookingController extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  void setMode(BookingMode mode) {
    if (mode == state.mode) return;
    // Category/quote are mode-specific — reset the tail of the flow.
    state = state.copyWith(mode: mode, selectedCategoryCode: null);
  }

  void setPickup(PlaceSuggestion place) {
    state = state.copyWith(pickup: place, selectedCategoryCode: null);
  }

  void setDrop(PlaceSuggestion place) {
    state = state.copyWith(drop: place, selectedCategoryCode: null);
  }

  void selectCategory(String code) {
    state = state.copyWith(selectedCategoryCode: code);
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setSchedule(DateTime? when) {
    state = when == null
        ? state.copyWith(clearScheduledAt: true)
        : state.copyWith(scheduledAt: when, clearScheduledAt: false);
  }

  void setGoods(GoodsDetails goods) {
    state = state.copyWith(goods: goods);
  }

  void setPromo(String? code) {
    state = code == null
        ? state.copyWith(clearPromo: true)
        : state.copyWith(promoCode: code, clearPromo: false);
  }

  void reset() => state = const BookingDraft();
}

final bookingControllerProvider =
    NotifierProvider<BookingController, BookingDraft>(BookingController.new);

/// One fare option row: category + its quote for the selected route.
class FareOption {
  const FareOption({required this.category, required this.quote});

  final ServiceCategory category;
  final FareQuote quote;
}

/// Quotes for every enabled category of the draft's mode and route.
/// Recomputed ONLY when mode/pickup/drop change (not on selection or payment
/// changes). All numbers come from [ApiContract.quote] — never client-computed.
final fareOptionsProvider = FutureProvider<List<FareOption>>((ref) async {
  final route = ref.watch(
    bookingControllerProvider.select((d) => (d.mode, d.pickup, d.drop, d.goods)),
  );
  final (mode, pickupPlace, dropPlace, goods) = route;
  final pickup = pickupPlace == null
      ? null
      : LocationPoint(
          lat: pickupPlace.lat,
          lng: pickupPlace.lng,
          address: pickupPlace.address,
        );
  final drop = dropPlace == null
      ? null
      : LocationPoint(
          lat: dropPlace.lat,
          lng: dropPlace.lng,
          address: dropPlace.address,
        );
  if (pickup == null || drop == null) return const [];

  final api = ref.watch(apiContractProvider);
  final kind = mode == BookingMode.goods ? ServiceKind.goods : ServiceKind.ride;
  final categories = await api.serviceCategories(city: 'blr', kind: kind);

  final options = await Future.wait(
    categories.map((category) async {
      try {
        final quote = await api.quote(
          kind: kind,
          serviceCategory: category.code,
          pickup: pickup,
          drop: drop,
          weightKg: goods?.weightKg,
          needsLoadingHelp: goods?.needsLoadingHelp ?? false,
        );
        return FareOption(category: category, quote: quote);
      } catch (_) {
        // A category that can't quote for this route is skipped, not fatal.
        return null;
      }
    }),
  );

  return options.whereType<FareOption>().toList();
});

/// Bookings feed for the Activity tab (newest first).
final bookingsProvider = FutureProvider<Paged<Booking>>(
  (ref) => ref.watch(apiContractProvider).bookings(),
);

/// The booking created by the confirm action — watched by the searching screen.
class ActiveBooking extends Notifier<Booking?> {
  @override
  Booking? build() => null;

  void set(Booking booking) => state = booking;

  void clear() => state = null;
}

final activeBookingProvider =
    NotifierProvider<ActiveBooking, Booking?>(ActiveBooking.new);

/// Proof-of-delivery evidence captured in-session (dual photos + signature).
/// In-memory for the mock build; the Phase 6 backend stores these as files.
class PodProof {
  const PodProof({
    this.photoPaths = const [],
    this.pickupPhotoPath,
    this.dropPhotoPath,
    this.pickupPhotoAt,
    this.dropPhotoAt,
    this.signaturePng,
    this.receiverName,
    this.otp,
  });

  final List<String> photoPaths;
  final String? pickupPhotoPath;
  final String? dropPhotoPath;
  final DateTime? pickupPhotoAt;
  final DateTime? dropPhotoAt;
  final Uint8List? signaturePng;
  final String? receiverName;
  final String? otp;
}

class PodProofController extends Notifier<PodProof?> {
  @override
  PodProof? build() => null;

  void set(PodProof proof) => state = proof;

  void clear() => state = null;
}

final podProofProvider =
    NotifierProvider<PodProofController, PodProof?>(PodProofController.new);
