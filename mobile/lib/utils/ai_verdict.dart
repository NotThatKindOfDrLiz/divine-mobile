enum AIVerdict { likely, probably }

AIVerdict? resolveAIVerdict(double? aiScore) {
  if (aiScore == null) return null;
  if (aiScore > 0.8) return AIVerdict.probably;
  if (aiScore > 0.5) return AIVerdict.likely;
  return null;
}

bool isHumanConfirmedAiScore(double? aiScore) {
  return aiScore != null && aiScore <= 0.5;
}

extension AIVerdictText on AIVerdict {
  String get badgeLabel {
    switch (this) {
      case AIVerdict.likely:
        return 'Likely AI';
      case AIVerdict.probably:
        return 'Probably AI';
    }
  }

  String get generatedDescription {
    switch (this) {
      case AIVerdict.likely:
        return 'likely AI-generated';
      case AIVerdict.probably:
        return 'probably AI-generated';
    }
  }
}
