import 'dart:math';

/// Daily inspirational words and greetings for the home screen
class InspirationService {
  InspirationService._();

  static final _random = Random();

  /// Get time-of-day greeting
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good night';
  }

  /// Get daily inspirational word (changes once per day)
  static String getDailyWord() {
    // Use day of year as seed for consistent daily word
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final index = dayOfYear % _inspirationalWords.length;
    return _inspirationalWords[index];
  }

  /// Get a random inspirational phrase
  static String getRandomPhrase() {
    return _inspirationalPhrases[_random.nextInt(_inspirationalPhrases.length)];
  }

  /// Get welcome back message with personal touch
  static String getWelcomeBackMessage() {
    return _welcomeBackMessages[_random.nextInt(_welcomeBackMessages.length)];
  }

  /// Beautiful inspirational words
  static const List<String> _inspirationalWords = [
    'breathe',
    'flow',
    'create',
    'dream',
    'wonder',
    'imagine',
    'express',
    'believe',
    'inspire',
    'resonate',
    'echo',
    'whisper',
    'bloom',
    'shine',
    'glow',
    'spark',
    'kindle',
    'illuminate',
    'dance',
    'soar',
    'wander',
    'discover',
    'unfold',
    'emerge',
    'transform',
    'evolve',
    'flourish',
    'thrive',
    'radiate',
    'embrace',
    'cherish',
    'nurture',
    'cultivate',
    'weave',
    'craft',
    'compose',
    'harmonize',
    'resound',
    'illuminate',
    'enchant',
  ];

  /// Gentle, encouraging phrases
  static const List<String> _inspirationalPhrases = [
    'Every great song starts with a single word',
    'Your words have power',
    'Let the rhythm guide you',
    'Write from the heart',
    'The muse is with you',
    'Your story matters',
    'Create without judgment',
    'Let the words flow',
    'Find your voice',
    'Write what sets your soul on fire',
    'Trust the process',
    'Embrace the journey',
    'Your creativity is limitless',
    'Every word counts',
    'Write with intention',
  ];

  /// Welcome back messages
  static const List<String> _welcomeBackMessages = [
    'Welcome back, wordsmith',
    'The words missed you',
    'Ready to create?',
    'Your muse has been waiting',
    'Time to write',
    "Let's make something beautiful",
    'Your creativity awaits',
    'Welcome back to your space',
  ];
}
