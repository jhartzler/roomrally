require 'rails_helper'

RSpec.describe TriviaQuestion, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:trivia_pack) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:options) }

    it 'validates options must be array of four' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: [ "A", "B", "C" ])
      expect(question).not_to be_valid
      expect(question.errors[:options]).to include("must contain exactly 4 choices")
    end

    it 'validates correct_answers must be present' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, correct_answers: [])
      expect(question).not_to be_valid
      expect(question.errors[:correct_answers]).to include("must have at least one selected")
    end

    it 'validates correct_answers must be an array' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, correct_answers: "Paris")
      expect(question).not_to be_valid
      expect(question.errors[:correct_answers]).to include("must have at least one selected")
    end

    it 'validates all correct_answers must be in options' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: [ "A", "B", "C", "D" ], correct_answers: [ "E" ])
      expect(question).not_to be_valid
      expect(question.errors[:correct_answers]).to include("must all be included in options")
    end

    it 'allows multiple correct answers' do
      trivia_pack = create(:trivia_pack)
      question = build(:trivia_question, trivia_pack:, options: [ "A", "B", "C", "D" ], correct_answers: [ "A", "B" ])
      expect(question).to be_valid
    end
  end

    describe 'image attachment' do
      it 'is valid with no image attached' do
        question = build(:trivia_question)
        expect(question).to be_valid
      end

      it 'is valid with an acceptable image type' do
        question = build(:trivia_question)
        question.image.attach(
          io: StringIO.new("fake image content"),
          filename: "photo.jpg",
          content_type: "image/jpeg"
        )
        expect(question).to be_valid
      end

      it 'is invalid with a disallowed content type' do
        question = build(:trivia_question)
        question.image.attach(
          io: StringIO.new("fake pdf content"),
          filename: "doc.pdf",
          content_type: "application/pdf"
        )
        expect(question).not_to be_valid
        expect(question.errors[:image]).to be_present
      end

      it 'is invalid when image exceeds 5MB' do
        question = build(:trivia_question)
        # Attach a blob whose byte_size is over the limit without uploading 5MB of data
        question.image.attach(
          io: StringIO.new("x"),
          filename: "big.jpg",
          content_type: "image/jpeg"
        )
        # Stub byte_size to simulate an oversized file
        allow(question.image.blob).to receive(:byte_size).and_return(6.megabytes)
        expect(question).not_to be_valid
        expect(question.errors[:image]).to be_present
      end
    end

  describe 'remove_image' do
    it 'purges the attachment when remove_image is set to "1" and saved' do
      question = create(:trivia_question)
      question.image.attach(
        io: StringIO.new("x"),
        filename: "test.png",
        content_type: "image/png"
      )
      expect(question.image).to be_attached

      question.update!(remove_image: "1")
      question.reload
      expect(question.image).not_to be_attached
    end
  end

  describe 'options' do
    it 'stores options as an array' do
      question = create(:trivia_question, options: [ "Paris", "London", "Berlin", "Madrid" ])
      expect(question.reload.options).to eq([ "Paris", "London", "Berlin", "Madrid" ])
    end
  end
end
