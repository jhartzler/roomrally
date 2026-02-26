class GameTemplate < ApplicationRecord
  belongs_to :user
  belongs_to :prompt_pack, optional: true
  belongs_to :trivia_pack, optional: true
  belongs_to :category_pack, optional: true
  has_many :rooms, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :game_type, presence: true, inclusion: { in: Room::GAME_TYPES }
  validate :pack_matches_game_type
  validate :pack_accessible_to_user
  validate :settings_within_bounds

  SETTING_BOUNDS = {
    "timer_increment"     => 10..300,
    "question_count"      => 1..50,
    "total_rounds"        => 1..10,
    "categories_per_round" => 1..12
  }.freeze

  before_validation :cast_settings

  SETTING_DEFAULTS = {
    "timer_enabled" => false,
    "timer_increment" => 90,
    "show_instructions" => true,
    "question_count" => 5,
    "total_rounds" => 3,
    "categories_per_round" => 6,
    "stage_only" => false
  }.freeze

  def merged_settings
    SETTING_DEFAULTS.merge(settings || {})
  end

  def pack
    case game_type
    when Room::WRITE_AND_VOTE then prompt_pack
    when Room::SPEED_TRIVIA then trivia_pack
    when Room::CATEGORY_LIST then category_pack
    end
  end

  def build_room
    Room.new(
      game_type:,
      user:,
      game_template: self,
      display_name: name,
      prompt_pack:,
      trivia_pack:,
      category_pack:,
      stage_only: merged_settings["stage_only"]
    )
  end

  private

  def cast_settings
    return if settings.blank?

    settings.each do |key, value|
      default = SETTING_DEFAULTS[key]
      settings[key] =
        case default
        when true, false then ActiveModel::Type::Boolean.new.cast(value)
        when Integer then value.to_i
        else value
        end
    end
  end

  def pack_matches_game_type
    if prompt_pack_id.present? && game_type != Room::WRITE_AND_VOTE
      errors.add(:prompt_pack, "doesn't match game type")
    end
    if trivia_pack_id.present? && game_type != Room::SPEED_TRIVIA
      errors.add(:trivia_pack, "doesn't match game type")
    end
    if category_pack_id.present? && game_type != Room::CATEGORY_LIST
      errors.add(:category_pack, "doesn't match game type")
    end
  end

  def settings_within_bounds
    return if settings.blank?

    SETTING_BOUNDS.each do |key, range|
      next unless settings.key?(key)

      value = settings[key]
      unless range.cover?(value)
        errors.add(:settings, "#{key.humanize} must be between #{range.min} and #{range.max}")
      end
    end
  end

  def pack_accessible_to_user
    [ prompt_pack, trivia_pack, category_pack ].compact.each do |pack|
      unless pack.user_id.nil? || pack.user_id == user_id
        errors.add(:base, "You don't have access to the selected pack")
      end
    end
  end
end
