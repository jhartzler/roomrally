class Response < ApplicationRecord
  belongs_to :player
  belongs_to :prompt_instance
end
