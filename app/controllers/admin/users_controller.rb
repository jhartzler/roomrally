class Admin::UsersController < Admin::BaseController
  def index
    @users = User.all
    render plain: "admin users"
  end
end
