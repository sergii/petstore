class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail to: user.email_address, subject: "Reset your Pet Store password"
  end
end
