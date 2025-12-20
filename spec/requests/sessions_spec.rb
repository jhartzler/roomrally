require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: '123456',
      info: {
        name: 'Test User',
        email: 'test@example.com',
        image: 'http://example.com/image.jpg'
      }
    })
  end

  describe "GET /auth/google_oauth2/callback" do
    context "when creating a new user" do
      it "creates a user" do
        expect {
          get "/auth/google_oauth2/callback"
        }.to change(User, :count).by(1)
      end

      it "logs the user in and redirects", :aggregate_failures do
        get "/auth/google_oauth2/callback"
        expect(session[:user_id]).to eq(User.last.id)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Welcome back, Test User!")
      end
    end

    context "when logging in existing user" do
      let!(:user) do
        User.create!(
          provider: 'google_oauth2',
          uid: '123456',
          name: 'Test User',
          email: 'test@example.com',
          password: 'password'
        )
      end

      it "does not create a new user" do
        expect {
          get "/auth/google_oauth2/callback"
        }.not_to change(User, :count)
      end

      it "logs in and redirects", :aggregate_failures do
        get "/auth/google_oauth2/callback"
        expect(session[:user_id]).to eq(user.id)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /logout" do
    before do
      User.create!(
        provider: 'google_oauth2',
        uid: '123456',
        name: 'Test User',
        email: 'test@example.com',
        password: 'password'
      )
      # Log in via callback since we can't set session directly
      get "/auth/google_oauth2/callback"
    end

    it "logs the user out", :aggregate_failures do
      delete "/logout"
      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Login with Google")
    end
  end
end
