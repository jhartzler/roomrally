class ContactsController < ApplicationController
  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)

    if @contact.valid?
      ContactMailer.contact_email(
        name: @contact.name,
        email: @contact.email,
        subject: @contact.subject,
        message: @contact.message
      ).deliver_later
      redirect_to root_path, notice: "Thanks for reaching out! We'll get back to you soon."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:name, :email, :subject, :message)
  end
end
