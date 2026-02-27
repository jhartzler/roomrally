require 'rails_helper'

RSpec.describe "Admin users index", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:other_user) { create(:user, name: "Jane Player", email: "jane@example.com") }

  before { sign_in(admin) }

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
