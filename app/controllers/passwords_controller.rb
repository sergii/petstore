class PasswordsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 3.minutes, only: :create
  before_action :set_user, only: %i[edit update]

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end
    redirect_to new_session_path, notice: "If that account exists, a reset link has been sent."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Password updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_password_path, alert: "Reset link is invalid or expired."
  end
end
