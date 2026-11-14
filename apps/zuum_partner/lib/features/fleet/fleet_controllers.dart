import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

final fleetOverviewProvider = FutureProvider<FleetOverview>(
  (ref) => ref.watch(partnerApiProvider).fleetOverview(),
);

final fleetDriversProvider = FutureProvider<List<FleetDriver>>(
  (ref) => ref.watch(partnerApiProvider).fleetDrivers(),
);

final fleetVehiclesProvider = FutureProvider<List<PartnerVehicle>>(
  (ref) => ref.watch(partnerApiProvider).fleetVehicles(),
);
