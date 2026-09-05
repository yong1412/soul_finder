class InterestData {
  static const Map<String, String> idToLabel = {
    'pet_lovers': 'Pet Lovers 🐾',
    'music': 'Music 🎵',
    'travel': 'Travel ✈️',
    'movies': 'Movies 🎬',
    'gaming': 'Gaming 🎮',
    'foodie': 'Foodie 🍕',
    'fitness': 'Fitness 💪',
    'reading': 'Reading 📚',
    'photography': 'Photography 📸',
    'art': 'Art 🎨',
    'tech': 'Tech 💻',
    'coding': 'Coding ⌨️',
    'sports': 'Sports ⚽',
    'nature': 'Nature 🌲',
    'coffee': 'Coffee ☕',
    'hiking': 'Hiking 🥾',
    'cooking': 'Cooking 🍳',
    'dance': 'Dance 💃',
    'yoga': 'Yoga 🧘',
    'fashion': 'Fashion ✨',
  };

  static String getLabel(String id) {
    return idToLabel[id] ?? id;
  }

  static String getId(String label) {
    return idToLabel.entries
        .firstWhere((entry) => entry.value == label, orElse: () => MapEntry(label, label))
        .key;
  }

  static List<String> get allLabels => idToLabel.values.toList();
  static List<String> get allIds => idToLabel.keys.toList();
}
