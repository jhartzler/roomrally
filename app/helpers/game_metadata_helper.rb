module GameMetadataHelper
  GAME_INFO = {
    "Write And Vote" => {
      emoji: "✍️",
      tagline: "Write hilarious answers, vote for the best",
      description: "Players write creative responses to prompts, then everyone votes on their favorites. Points for getting votes.",
      player_count: "3–16 players",
      duration: "10–20 min",
      how_it_works: [
        "Everyone gets a prompt and writes a response",
        "All answers are shown — players vote for their favorite",
        "Points awarded for votes received"
      ]
    },
    "Speed Trivia" => {
      emoji: "⚡",
      tagline: "Race to answer trivia questions the fastest",
      description: "Quick-fire trivia rounds where speed matters. The faster you answer correctly, the more points you earn.",
      player_count: "2–16 players",
      duration: "5–15 min",
      how_it_works: [
        "A trivia question appears on the Stage",
        "Players race to tap the correct answer on their phones",
        "Faster correct answers earn more points"
      ]
    },
    "Category List" => {
      emoji: "📋",
      tagline: "Fill in categories before time runs out",
      description: "Players get a letter and a list of categories — fill in as many as you can before the timer runs out. Unique answers score more.",
      player_count: "2–16 players",
      duration: "10–20 min",
      how_it_works: [
        "A random letter and categories appear each round",
        "Players fill in answers starting with that letter",
        "Unique answers score higher — duplicates score less"
      ]
    }
  }.freeze

  SETTING_DESCRIPTIONS = {
    show_instructions: "Shows a how-to-play screen before the game starts. Recommended for first-time players.",
    timer_enabled: "Automatically ends rounds after a set time. Without this, rounds wait for all players to submit.",
    timer_increment: "How long each timed round lasts (10–300 seconds).",
    question_count: "Number of trivia questions. More questions = longer game.",
    categories_per_round: "How many categories players fill in each round.",
    total_rounds: "Total number of rounds to play."
  }.freeze

  def game_info(game_type)
    GAME_INFO[game_type] || {}
  end

  def setting_description(setting_key)
    SETTING_DESCRIPTIONS[setting_key]
  end
end
