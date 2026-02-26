require 'rails_helper'

RSpec.describe "TriviaPack image management", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "POST /trivia_packs — creating a question with an image" do
    it "attaches the uploaded image to the question" do
      post trivia_packs_path, params: {
        trivia_pack: {
          name: "Image Pack",
          trivia_questions_attributes: {
            "0" => {
              body: "Which planet is red?",
              options: [ "Mars", "Venus", "Earth", "Jupiter" ],
              correct_answers: [ "Mars" ],
              image: fixture_file_upload(
                Rails.root.join("spec/fixtures/files/test_image.png"),
                "image/png"
              )
            }
          }
        }
      }

      pack = TriviaPack.last
      expect(response).to redirect_to(edit_trivia_pack_path(pack))
      question = pack.trivia_questions.first
      expect(question.image).to be_attached
      expect(question.image.filename.to_s).to eq("test_image.png")
    end

    it "rejects an image with a disallowed content type" do
      # Use a pre-created blob with identify: false so content_type is preserved as-is.
      # This mirrors the DirectUpload production flow (blob exists before form submit).
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake pdf content"),
        filename: "doc.pdf",
        content_type: "application/pdf",
        identify: false
      )

      post trivia_packs_path, params: {
        trivia_pack: {
          name: "Bad Image Pack",
          trivia_questions_attributes: {
            "0" => {
              body: "Which planet is red?",
              options: [ "Mars", "Venus", "Earth", "Jupiter" ],
              correct_answers: [ "Mars" ],
              image: blob.signed_id
            }
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(TriviaPack.count).to eq(0)
    end
  end

  describe "PATCH /trivia_packs/:id — removing an image" do
    let(:pack) { create(:trivia_pack, user:) }
    let(:question) { create(:trivia_question, trivia_pack: pack) }

    before do
      question.image.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test_image.png")),
        filename: "test_image.png",
        content_type: "image/png"
      )
    end

    it "purges the image when remove_image is submitted" do
      patch trivia_pack_path(pack), params: {
        trivia_pack: {
          trivia_questions_attributes: {
            "0" => {
              id: question.id,
              body: question.body,
              options: question.options,
              correct_answers: question.correct_answers,
              remove_image: "1"
            }
          }
        }
      }

      expect(response).to redirect_to(trivia_packs_path)
      question.reload
      expect(question.image).not_to be_attached
    end

    it "keeps the image when remove_image is not submitted" do
      patch trivia_pack_path(pack), params: {
        trivia_pack: {
          trivia_questions_attributes: {
            "0" => {
              id: question.id,
              body: question.body,
              options: question.options,
              correct_answers: question.correct_answers
            }
          }
        }
      }

      expect(response).to redirect_to(trivia_packs_path)
      question.reload
      expect(question.image).to be_attached
    end
  end
end
