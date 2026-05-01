import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/explore_service.dart';
import '../../../../data/models/explore_destination.dart';

final exploreServiceProvider = Provider<ExploreService>((ref) {
  return ExploreService();
});

final popularDestinationsProvider = FutureProvider<List<ExploreDestination>>((ref) async {
  return ref.watch(exploreServiceProvider).getPopularDestinations();
});

final searchDestinationsProvider = FutureProvider.family<List<ExploreDestination>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.watch(exploreServiceProvider).searchDestinations(query);
});

final categoryDestinationsProvider = FutureProvider.family<List<ExploreDestination>, String>((ref, category) async {
  return ref.watch(exploreServiceProvider).getDestinationsByCategory(category);
});
