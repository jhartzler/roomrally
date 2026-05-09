class FixHuntForeignKeys < ActiveRecord::Migration[8.1]
  def change
    # P0: Add FK for winner_submission_id with nullify on delete.
    # Without this, deleting a hunt_submission that is referenced as a winner
    # will leave an invalid ID or raise a FK violation.
    add_foreign_key :hunt_prompt_instances, :hunt_submissions,
                    column: :winner_submission_id,
                    on_delete: :nullify

    # P0: Match other pack types by nullifying the reference when a hunt_pack
    # is deleted, so game_templates and rooms don't hard-block pack deletion.
    remove_foreign_key :game_templates, :hunt_packs
    add_foreign_key :game_templates, :hunt_packs, on_delete: :nullify

    remove_foreign_key :rooms, :hunt_packs
    add_foreign_key :rooms, :hunt_packs, on_delete: :nullify
  end
end
