# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Studio navigation", type: :system do
  let(:user) { create(:user, name: "Jane Host") }
  let!(:game_template) { create(:game_template, user:, name: "Trivia Night") }
  let!(:prompt_pack) { create(:prompt_pack, user:, name: "Funny Prompts") }

  before { sign_in(user) }

  describe "persistent sidebar" do
    it "appears on the dashboard page with all three nav links" do
      visit dashboard_path

      within("aside") do
        expect(page).to have_link("Overview")
        expect(page).to have_link("My Games")
        expect(page).to have_link("Content Packs")
      end
    end

    it "appears on the game templates index" do
      visit game_templates_path

      within("aside") do
        expect(page).to have_link("Overview")
        expect(page).to have_link("My Games")
        expect(page).to have_link("Content Packs")
      end
    end

    it "appears on the pack edit page" do
      visit edit_prompt_pack_path(prompt_pack)

      within("aside") do
        expect(page).to have_link("Overview")
        expect(page).to have_link("My Games")
        expect(page).to have_link("Content Packs")
      end
    end

    it "highlights Overview on the dashboard" do
      visit dashboard_path

      within("aside") do
        overview_link = find_link("Overview")
        expect(overview_link[:class]).to include("bg-white/15")
      end
    end

    it "highlights My Games on the game templates page" do
      visit game_templates_path

      within("aside") do
        games_link = find_link("My Games")
        expect(games_link[:class]).to include("bg-white/15")

        overview_link = find_link("Overview")
        expect(overview_link[:class]).not_to include("bg-white/15")
      end
    end

    it "highlights Content Packs on the customize page" do
      visit customize_path

      within("aside") do
        packs_link = find_link("Content Packs")
        expect(packs_link[:class]).to include("bg-white/15")

        overview_link = find_link("Overview")
        expect(overview_link[:class]).not_to include("bg-white/15")
      end
    end

    it "shows the user's name and initial" do
      visit dashboard_path

      within("aside") do
        expect(page).to have_text("Jane Host")
        expect(page).to have_text("J")
      end
    end
  end

  describe "breadcrumbs" do
    it "shows breadcrumb trail on game template edit" do
      visit edit_game_template_path(game_template)

      expect(page).to have_link("Studio", href: dashboard_path)
      expect(page).to have_link("My Games", href: game_templates_path)
      expect(page).to have_text("Trivia Night")
    end

    it "shows breadcrumb trail on pack edit" do
      visit edit_prompt_pack_path(prompt_pack)

      expect(page).to have_link("Studio", href: dashboard_path)
      expect(page).to have_link("Content Packs", href: customize_path)
      expect(page).to have_link("Prompt Packs", href: prompt_packs_path)
      expect(page).to have_text("Funny Prompts")
    end

    it "navigates back via breadcrumb links" do
      visit edit_prompt_pack_path(prompt_pack)

      click_link "Prompt Packs"
      expect(page).to have_current_path(prompt_packs_path)
    end

    it "navigates to Studio root via breadcrumb" do
      visit edit_game_template_path(game_template)

      click_link "Studio"
      expect(page).to have_current_path(dashboard_path)
    end
  end

  describe "cross-section navigation" do
    it "navigates from pack edit to game templates via sidebar" do
      visit edit_prompt_pack_path(prompt_pack)

      within("aside") do
        click_link "My Games"
      end

      expect(page).to have_current_path(game_templates_path)
    end

    it "navigates from game templates to content packs via sidebar" do
      visit game_templates_path

      within("aside") do
        click_link "Content Packs"
      end

      expect(page).to have_current_path(customize_path)
    end

    it "navigates from content packs to dashboard via sidebar" do
      visit customize_path

      within("aside") do
        click_link "Overview"
      end

      expect(page).to have_current_path(dashboard_path)
    end
  end
end
