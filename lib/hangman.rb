# frozen_string_literal: false

MAX_FAILS = 10
SAVED_GAMES_DIR = 'saved_games/'.freeze

require 'yaml'

# Holds information about overall gamestate
class Game
  attr_reader :answer, :incorrect_guess_count, :hint, :guesses

  MIN_WORD_SIZE = 5
  MAX_WORD_SIZE = 12

  def initialize(answer = pick_random_word)
    @answer = answer
    @incorrect_guess_count = 0
    @hint = Hint.new(answer.length)
    @guesses = []
  end

  def process_guess
    guess_str = 'Guess a single character (insensitive). Type save if you would like to save instead.'
    puts guess_str
    guess = gets.chomp
    until (valid_input?(guess) && new_guess?(guess)) || guess == 'save'
      puts "Incorrect format or previous guess. #{guess_str}"
      guess = gets.chomp
    end
    guess == 'save' ? 'save' : update_guesses(guess)
  end

  def print_guesses
    guesses.reduce('') { |all_guesses, guess| all_guesses + guess.to_s }
  end

  def end_conditions
    (incorrect_guess_count >= MAX_FAILS) || (hint.hint_string == answer)
  end

  private

  attr_writer :guesses, :incorrect_guess_count

  def pick_random_word
    words = File.readlines('lib/dictionary.txt')
    answer = words.sample.rstrip
    answer = words.sample.rstrip until answer.length.between?(MIN_WORD_SIZE, MAX_WORD_SIZE)
    answer
  end

  def update_guesses(character)
    guesses << Guess.new(character, answer)
    guesses[-1].correct ? hint.update_hint_string(character, answer) : self.incorrect_guess_count += 1
    guesses[-1].correct
  end

  def valid_input?(guess)
    guess.match?(/\A[A-Za-z]\z/)
  end

  def new_guess?(guess)
    !concat_guesses.include?(guess)
  end

  def concat_guesses
    guesses.reduce('') { |all_guesses, guess| all_guesses + guess.guess }
  end
end

# Holds information about an individual hint
class Hint
  attr_reader :hint_string

  def initialize(length)
    @hint_string = '_' * length
  end

  def update_hint_string(character, answer)
    self.hint_string = find_matches(character, answer)
  end

  def to_s
    hint_string.gsub('', ' ')
  end

  private

  attr_writer :hint_string

  def find_matches(character, answer)
    matches = (0...answer.length).find_all { |i| answer[i].downcase == character }
    matches.each { |i| hint_string[i] = answer[i] }
    hint_string
  end
end

# Holds information about individual guesses
class Guess
  attr_reader :guess, :correct

  def initialize(character, answer)
    @guess = character
    @correct = check_guess(answer)
  end

  def to_s
    guess.format(correct)
  end

  private

  def check_guess(answer)
    answer.downcase.include?(guess)
  end
end

# Provide easy formatting of correct and incorrect guesses
class String
  RESET_CODE = "\u001b[0m".freeze
  RED_TEXT = "\u001b[31m".freeze
  CYAN_TEXT = "\u001b[36m".freeze

  def format(type)
    type ? format_correct : format_incorrect
  end

  private

  def format_correct
    "#{CYAN_TEXT} #{self} #{RESET_CODE}"
  end

  def format_incorrect
    "#{RED_TEXT} #{self} #{RESET_CODE}"
  end
end

def play_round(game)
  puts "You have #{MAX_FAILS - game.incorrect_guess_count} fails remaining."
  puts "\nHere is the current hint string."
  puts game.hint
  puts "\nHere are your guesses so far"
  puts game.print_guesses
  result = game.process_guess
  'save' if result == 'save'
end

def play_game
  instructions
  game = load_game? ? load_game : Game.new
  until game.end_conditions
    result = play_round(game)
    break if result == 'save'
  end
  if result == 'save'
    save_game(game)
    return nil
  end

  game.hint.hint_string == game.answer ? 'You won!' : 'You lost :('
  puts "The answer was #{game.answer}."
end

def load_game?
  puts "\n\nWould you like to start a new game or load an existing game?"
  puts 'Here are the existing games:'
  print_saved_games
  choice = ''
  until %w[l a].include?(choice)
    puts "Type 'l' to load an existing game or 'n' to start a new game."
    choice = gets.chomp
  end
  choice == 'l'
end

def instructions
  puts "\nThis is a game of hangman. You are allowed to make #{MAX_FAILS} incorrect guesses before you lose."
  puts 'Between each guess, you will see the number of fails remaining and the guesses you have made.'
  puts "For letters that are incorrect, they will appear #{'like this'.format(false)}."
  puts "For letters that are correct, they will appear #{'like this'.format(true)}."
end

def save_game(game)
  bad_file = 'Invalid filename. You must use letters, numbers, underscores, and spaces and do not start with spaces.'
  puts 'What would you like to name the save file? Below are the current saved games.'
  Dir.chdir(SAVED_GAMES_DIR)
  print_saved_games
  filename = gets.chomp
  puts bad_file until good_file_name?(filename)
  File.open("#{filename}.yml", 'w') { |file| file.write(game.to_yaml) }
  Dir.chdir('../')
end

def print_saved_games
  games = Dir.glob('*.yml')
  games.each_with_index { |game, num| puts "#{num + 1}) #{game.delete_suffix('.yml')}" }
end

def good_file_name?(filename)
  bad_match = filename.match?(/ \z/) || filename.match?(/\A /)
  good_match = filename.match?(/[a-zA-z0-9_ ]/)
  good_match && !bad_match
end

def load_game
  Dir.chdir(SAVED_GAMES_DIR)
  filename = choose_file
  return nil if filename.nil?

  game = YAML.safe_load(File.read(filename), permitted_classes: [Game, Hint, Guess])
  Dir.chdir('../')
  game
end

def choose_file
  games = Dir.glob('*.yml')
  print_load_prompt
  option = gets.chomp
  until option == 'q' || !games[option.to_i - 1].nil?
    puts 'Invalid selection. What game would you like to load? Choose the game number or enter q to quit prompt.'
    option = gets.chomp
  end
  option == 'q' ? nil : games[option.to_i - 1]
end

def print_load_prompt
  puts 'Which game would you like to load? Choose the game number or enter q to quit prompt.'
  print_saved_games
end

# play_game
