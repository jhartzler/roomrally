require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations" do
    let(:valid_attributes) { { name: 'Test User', email: 'test@example.com', password: 'password' } }

    it "is valid with valid attributes" do
      user = described_class.new(valid_attributes)
      expect(user).to be_valid
    end

    it "requires an email" do
      user = described_class.new(name: 'Test User', password: 'password')
      expect(user).not_to be_valid
    end

    it "requires a unique email" do
      described_class.create!(valid_attributes)
      user = described_class.new(name: 'User 2', email: 'test@example.com', password: 'password')
      expect(user).not_to be_valid
    end
  end

  describe ".from_omniauth" do
    let(:auth) do
      OmniAuth::AuthHash.new({
        provider: 'google_oauth2',
        uid: '123456',
        info: {
          name: 'Test User',
          email: 'test@example.com',
          image: 'http://example.com/image.jpg'
        }
      })
    end

    context "when user does not exist" do
      it "creates a new user" do
        expect {
          described_class.from_omniauth(auth)
        }.to change(described_class, :count).by(1)
      end

      it "sets the user attributes correctly", :aggregate_failures do
        user = described_class.from_omniauth(auth)
        expect(user.name).to eq('Test User')
        expect(user.email).to eq('test@example.com')
        expect(user.uid).to eq('123456')
        expect(user.provider).to eq('google_oauth2')
      end
    end

    context "when user exists" do
      let!(:existing_user) do
        described_class.create!(
          provider: 'google_oauth2',
          uid: '123456',
          name: 'Old Name',
          email: 'test@example.com',
          password: 'password'
        )
      end

      it "does not create a new user" do
        expect {
          described_class.from_omniauth(auth)
        }.not_to change(described_class, :count)
      end

      it "returns the existing user" do
        expect(described_class.from_omniauth(auth)).to eq(existing_user)
      end
    end
  end
end
