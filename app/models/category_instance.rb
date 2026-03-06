class CategoryInstance < ApplicationRecord
  belongs_to :category_list_game
  belongs_to :category
  has_many :category_answers, dependent: :destroy

  # Returns answers with auto-duplicate detection applied.
  # Each answer gets `auto_duplicate?` and `effectively_struck?` virtual attributes.
  # Optionally filter out hidden answers with exclude_hidden: true.
  def answers_with_duplicate_detection(exclude_hidden: false)
    scope = category_answers.includes(:player)
    scope = scope.where.not(status: :hidden) if exclude_hidden
    answers = scope.to_a

    normalized_groups = answers.group_by { |a| Games::CategoryList.normalize_answer(a.body) }
    duplicate_norms = normalized_groups
      .select { |norm, group| norm.present? && group.size > 1 }
      .keys.to_set

    answers.each do |answer|
      norm = Games::CategoryList.normalize_answer(answer.body)
      answer.auto_duplicate = duplicate_norms.include?(norm) && !answer.rejected? && !answer.duplicate?
    end

    answers
  end
end
