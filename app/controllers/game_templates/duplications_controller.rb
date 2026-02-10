# frozen_string_literal: true

module GameTemplates
  class DuplicationsController < ApplicationController
    before_action :authenticate_user!

    def create
      source = current_user.game_templates.find(params[:game_template_id])

      redirect_to new_game_template_path(
        game_template: {
          name: "#{source.name} (copy)",
          game_type: source.game_type,
          settings: source.settings,
          prompt_pack_id: source.prompt_pack_id,
          trivia_pack_id: source.trivia_pack_id,
          category_pack_id: source.category_pack_id
        }
      )
    end
  end
end
