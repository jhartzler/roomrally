class ContactMailer < ApplicationMailer
  def contact_email(name:, email:, subject:, message:)
    @name = name
    @email = email
    @subject = subject
    @message = message

    mail(
      to: Rails.application.credentials.dig(:contact, :email) || "support@roomrally.app",
      reply_to: email,
      subject: "[RoomRally Contact] #{subject}"
    )
  end
end
