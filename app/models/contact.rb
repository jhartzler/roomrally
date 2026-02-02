class Contact
  include ActiveModel::Model
  include ActiveModel::Validations

  attr_accessor :name, :email, :subject, :message

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true
  validates :message, presence: true
end
