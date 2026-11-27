class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 3.minutes, only: :create

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.expect(user: %i[name email_address password password_confirmation]))
    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Welcome to Pet Store!"
    else
      render :new, status: :unprocessable_entity
    end
  end
end
