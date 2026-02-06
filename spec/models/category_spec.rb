require "rails_helper"

RSpec.describe Category, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:category_pack) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end
end
