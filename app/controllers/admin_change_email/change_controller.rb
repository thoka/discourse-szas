# frozen_string_literal: true

module ::AdminChangeEmail
  class ChangeController < ::Admin::AdminController #ApplicationController # ::Admin::AdminController
    requires_plugin "discourse-szas"
    skip_before_action :verify_authenticity_token

    # before_action :ensure_admin

    def ensure_params
      params.require(:user_id)
      @user = User.find(params[:user_id])
      raise Discourse::InvalidParameters.new(:user_id) if @user.blank?
      params.require(:new_email)
      @email = params[:new_email]
      @email = @email.downcase

      raise Discourse::InvalidParameters.new(:new_email) unless @email =~ URI::MailTo::EMAIL_REGEXP
    end

    def echo
      ensure_params
      render json: {
               user_id: @user.id,
               new_email: @email,
               time: Time.now,
               reques_method: request.request_method,
             }
    rescue => e
      render json: { error: e.message }, status: 422
    end

    def update
      ensure_admin
      ensure_params

      UserEmail.where(user_id: @user.id).update_all(primary: false)

      existing_mail = UserEmail.find_by(email: @email)
      if existing_mail.present?
        if existing_mail.user_id != @user.id
          raise "email already exists"
        else
          existing_mail.update(primary: true)
          render json: success_json
          return
        end
      end

      puts "🔵🔵User emails: #{@user.emails}"
      UserEmail.new(email: @email, user_id: @user.id, primary: true).save!
      render json: success_json
    rescue => e
      render json: { error: e.message }, status: 422
    end
  end
end
