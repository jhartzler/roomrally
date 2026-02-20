# frozen_string_literal: true

module GameTemplates
  class LaunchesController < ApplicationController
    before_action :authenticate_user!

    def create
      @game_template = current_user.game_templates.find(params[:game_template_id])
      room = @game_template.build_room

      if room.save
        Analytics.track(
          distinct_id: "user_#{current_user.id}",
          event: "room_created",
          properties: { game_type: room.game_type, room_code: room.code, from_template: true, template_id: @game_template.id }
        )
        redirect_to room_backstage_path(room)
      else
        redirect_to game_templates_path, alert: "Could not launch game: #{room.errors.full_messages.to_sentence}"
      end
    end
  end
end
