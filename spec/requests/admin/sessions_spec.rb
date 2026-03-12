require "rails_helper"

RSpec.describe "Admin::Sessions" do
  let(:admin) { create(:user, :admin) }
  let(:non_admin) { create(:user) }

  describe "GET /admin/sessions" do
    it "requires admin access" do
      sign_in(non_admin)
      get admin_sessions_path
      expect(response).to redirect_to(root_path)
    end

    it "renders for admin users" do
      sign_in(admin)
      get admin_sessions_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /admin/sessions/:code" do
    let(:room) { create(:room) }

    it "requires admin access" do
      sign_in(non_admin)
      get admin_session_path(room.code)
      expect(response).to redirect_to(root_path)
    end

    it "renders for admin users" do
      sign_in(admin)
      get admin_session_path(room.code)
      expect(response).to have_http_status(:ok)
    end
  end
end
