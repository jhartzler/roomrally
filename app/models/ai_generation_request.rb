class AiGenerationRequest < ApplicationRecord
  belongs_to :user

  PROMPT_PACK_TYPE = "prompt_pack"
  TRIVIA_PACK_TYPE = "trivia_pack"
  CATEGORY_PACK_TYPE = "category_pack"
  PACK_TYPES = [ PROMPT_PACK_TYPE, TRIVIA_PACK_TYPE, CATEGORY_PACK_TYPE ].freeze

  enum :status, { pending: 0, processing: 1, succeeded: 2, failed: 3 }

  validates :pack_type, presence: true, inclusion: { in: PACK_TYPES }
  validates :pack_id, presence: true
  validates :user_theme, presence: true

  def target_pack
    case pack_type
    when PROMPT_PACK_TYPE then user.prompt_packs.find(pack_id)
    when TRIVIA_PACK_TYPE then user.trivia_packs.find(pack_id)
    when CATEGORY_PACK_TYPE then user.category_packs.find(pack_id)
    end
  end

  def items_for_indices(indices)
    return parsed_items if indices.blank?
    indices.map(&:to_i).filter_map { |i| parsed_items[i] }
  end
end
