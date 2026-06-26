enum ChatToolType {
  generateQuiz,
  generateFlashcard,
}

extension ChatToolTypeX on ChatToolType {
  String get label => switch (this) {
        ChatToolType.generateQuiz => 'Generate Quiz',
        ChatToolType.generateFlashcard => 'Generate Flashcard',
      };

  String get storageKey => switch (this) {
        ChatToolType.generateQuiz => 'generate_quiz',
        ChatToolType.generateFlashcard => 'generate_flashcard',
      };

  static ChatToolType? fromStorageKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final tool in ChatToolType.values) {
      if (tool.storageKey == key) return tool;
    }
    return null;
  }
}
