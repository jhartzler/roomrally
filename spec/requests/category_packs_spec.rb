require 'rails_helper'

RSpec.describe "CategoryPacks", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /index" do
    it "returns http success" do
      get category_packs_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_category_pack_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    let(:valid_attributes) do
      {
        name: "Animals Pack",
        game_type: "Category List",
        status: "draft",
        categories_attributes: [
          { name: "Mammals" },
          { name: "Birds" }
        ]
      }
    end

    it "creates a new CategoryPack with categories" do
      expect {
        post category_packs_path, params: { category_pack: valid_attributes }
      }.to change(CategoryPack, :count).by(1).and change(Category, :count).by(2)

      expect(response).to redirect_to(%r{/category_packs/\d+/edit})
    end
  end

  describe "GET /edit" do
    let(:category_pack) { create(:category_pack, user:) }

    it "returns http success" do
      get edit_category_pack_path(category_pack)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /update" do
    let(:category_pack) { create(:category_pack, user:) }

    it "updates and redirects" do
      patch category_pack_path(category_pack), params: { category_pack: { name: "Updated Name" } }
      expect(response).to redirect_to(category_packs_path)
    end
  end

  describe "DELETE /destroy" do
    let!(:category_pack) { create(:category_pack, user:) }

    it "destroys and redirects" do
      expect {
        delete category_pack_path(category_pack)
      }.to change(CategoryPack, :count).by(-1)
      expect(response).to redirect_to(category_packs_path)
    end
  end

  describe "authentication" do
    it "redirects unauthenticated users" do
      # Start a fresh session without signing in
      get category_packs_path, headers: { "Cookie" => "" }
      # Rails session-based auth redirects; assert not 200
      expect(response).not_to have_http_status(:success)
    end
  end
end
