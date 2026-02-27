require 'rails_helper'

RSpec.describe "Admin users", type: :system do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  describe "index" do
    let!(:other_user) { create(:user, name: "Jane Player", email: "jane@example.com") }

    it "lists all users with their names and emails" do
      visit admin_users_path
      expect(page).to have_content("Jane Player")
      expect(page).to have_content("jane@example.com")
    end

    it "shows AI usage for a user with requests" do
      create(:ai_generation_request, user: other_user, counts_against_limit: true,
             created_at: 1.hour.ago)
      visit admin_users_path
      expect(page).to have_content("1 / 10")
    end

    it "links to user detail page" do
      visit admin_users_path
      click_on "Jane Player"
      expect(page).to have_current_path(admin_user_path(other_user))
    end
  end

  describe "detail" do
    let!(:target_user) { create(:user, name: "Bob Host", email: "bob@example.com") }

    it "shows AI usage stats on the detail page" do
      create(:ai_generation_request, user: target_user, counts_against_limit: true,
             created_at: 1.hour.ago)
      visit admin_user_path(target_user)
      expect(page).to have_content("1 / 10")
      expect(page).to have_button("Reset AI Limit")
    end

    it "shows engagement stats" do
      create(:room, user: target_user)
      visit admin_user_path(target_user)
      expect(page).to have_content("1")  # rooms created
    end

    it "resets AI limit and shows success flash" do
      create(:ai_generation_request, user: target_user, counts_against_limit: true,
             created_at: 1.hour.ago)
      visit admin_user_path(target_user)
      click_button "Reset AI Limit"
      expect(page).to have_content("AI limit reset for Bob Host")
      expect(page).to have_content("0 / 10")
    end
  end
end
