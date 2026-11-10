/// Every tunable number in the game loop lives here.
class GameConfig {
  const GameConfig._();

  // --- XP ---
  /// XP per estimated minute of a quest.
  static const double xpPerMinute = 1.0;
  static const int minQuestXp = 10;
  static const double lowPriorityMult = 0.8;
  static const double normalPriorityMult = 1.0;
  static const double highPriorityMult = 1.25;

  /// Penalty quests (rolled over from a missed day) pay this fraction.
  static const double penaltyQuestMult = 0.5;

  /// Bonus for clearing every quest of the day.
  static const int dailyClearBonusXp = 50;

  /// XP lost when the distraction budget is blown. Never drops a level.
  static const int budgetBlownXpLoss = 50;

  // --- Levels ---
  /// XP needed to go from level n to n+1 is base + step * (n - 1).
  static const int levelBaseXp = 100;
  static const int levelStepXp = 50;

  /// Lowest level of each rank, ascending.
  static const Map<String, int> rankFloors = {
    'E': 1,
    'D': 5,
    'C': 10,
    'B': 20,
    'A': 35,
    'S': 50,
  };

  // --- Planning defaults (editable in Settings) ---
  static const int defaultWeekdayCapacityMin = 120;
  static const int defaultWeekendCapacityMin = 240;
  static const int defaultDistractionBudgetMin = 45;

  /// The planner never looks further ahead than this.
  static const int maxPlanHorizonDays = 28;

  // --- Deviation ---
  /// Fraction of the budget at which the System starts warning.
  static const double warnAtBudgetFraction = 0.8;

  /// After this hour, being under half of planned minutes is a warning.
  static const int behindCheckHour = 18;

  // --- LLM ---
  static const String defaultModel = 'gemini-3.5-flash-lite';
  static const int chatHistoryTurns = 4;
  static const int maxReplyTokens = 220;
  static const int maxPlanTokens = 400;
}
