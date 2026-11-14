import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

/// Shared wallet state — watched by the wallet tab and refreshed after
/// trip payments and top-ups.
final walletProvider = FutureProvider<Wallet>(
  (ref) => ref.watch(apiContractProvider).wallet(),
);

final walletTxProvider = FutureProvider<Paged<WalletTransaction>>(
  (ref) => ref.watch(apiContractProvider).walletTransactions(),
);
