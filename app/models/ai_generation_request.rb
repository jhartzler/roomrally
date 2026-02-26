class AiGenerationRequest < ApplicationRecord
  belongs_to :user

  PACK_TYPES = %w[prompt_pack trivia_pack category_pack].freeze

  enum :status, { pending: 0, processing: 1, succeeded: 2, failed: 3 }

  validates :pack_type, presence: true, inclusion: { in: PACK_TYPES }
  validates :pack_id, presence: true
  validates :user_theme, presence: true

  def target_pack
    case pack_type
    when "prompt_pack" then user.prompt_packs.find(pack_id)
    when "trivia_pack" then user.trivia_packs.find(pack_id)
    when "category_pack" then user.category_packs.find(pack_id)
    end
  end

  def items_for_indices(indices)
    return parsed_items if indices.blank?
    indices.map(&:to_i).filter_map { |i| parsed_items[i] }
  end
end
