import '../../data/models/explore_destination.dart';

class ExploreService {
  final List<ExploreDestination> _destinations = [
    ExploreDestination(
      id: '1',
      name: 'Maldives',
      category: 'Beaches',
      imageUrl: 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?q=80&w=1000&auto=format&fit=crop',
      rating: 4.9,
      description: 'Stunning white sand beaches and crystal clear waters.',
    ),
    ExploreDestination(
      id: '2',
      name: 'Swiss Alps',
      category: 'Mountains',
      imageUrl: 'https://images.unsplash.com/photo-1531310197839-ccf54634509e?q=80&w=1000&auto=format&fit=crop',
      rating: 4.8,
      description: 'Breathtaking mountain views and winter sports.',
    ),
    ExploreDestination(
      id: '3',
      name: 'Tokyo',
      category: 'Cities',
      imageUrl: 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?q=80&w=1000&auto=format&fit=crop',
      rating: 4.7,
      description: 'A vibrant mix of traditional culture and modern technology.',
    ),
    ExploreDestination(
      id: '4',
      name: 'Bali',
      category: 'Beaches',
      imageUrl: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?q=80&w=1000&auto=format&fit=crop',
      rating: 4.6,
      description: 'Tropical paradise with rich cultural heritage.',
    ),
    ExploreDestination(
      id: '5',
      name: 'Amazon Rainforest',
      category: 'Forest',
      imageUrl: 'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?q=80&w=1000&auto=format&fit=crop',
      rating: 4.5,
      description: 'Discover the world\'s largest tropical rainforest.',
    ),
  ];

  Future<List<ExploreDestination>> getPopularDestinations() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network
    return _destinations;
  }

  Future<List<ExploreDestination>> getDestinationsByCategory(String category) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _destinations.where((d) => d.category == category).toList();
  }

  Future<List<ExploreDestination>> searchDestinations(String query) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _destinations
        .where((d) => d.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
