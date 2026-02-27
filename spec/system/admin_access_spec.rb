require 'rails_helper'

RSpec.describe "Admin access control", type: :system do
  let(:regular_user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }

  context "when not logged in" do
    it "redirects to root" do
      visit admin_users_path
      expect(page).to have_current_path(root_path)
    end
  end

  context "when logged in as regular user" do
    before { sign_in(regular_user) }

    it "redirects to root with alert" do
      visit admin_users_path
      expect(page).to have_current_path(root_path)
    end
  end

  context "when logged in as admin" do
    before { sign_in(admin_user) }

    it "allows access to admin users list" do
      visit admin_users_path
      expect(page).to have_current_path(admin_users_path)
    end
  end
end
