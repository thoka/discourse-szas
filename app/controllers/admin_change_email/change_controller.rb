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

      # primary=false: eine Sekundaeradresse eintragen, ohne die
      # bestehende Primaeradresse anzufassen. Vorgabe true haelt das
      # bisherige Verhalten unveraendert (der Parameter ist neu).
      primary = ActiveModel::Type::Boolean.new.cast(params.fetch(:primary, true))

      existing_mail = UserEmail.find_by(email: @email)
      if existing_mail.present? && existing_mail.user_id != @user.id
        raise "email already exists"
      end

      if primary
        UserEmail.where(user_id: @user.id).update_all(primary: false)
        if existing_mail.present?
          existing_mail.update!(primary: true)
        else
          UserEmail.create!(email: @email, user_id: @user.id, primary: true)
        end
      elsif existing_mail.blank?
        # Ist die Adresse schon irgendeine Adresse dieses Kontos (primaer
        # oder sekundaer), bleibt sie unangetastet - "als Sekundaeradresse
        # eintragen" stuft keine bestehende Primaeradresse herab.
        UserEmail.create!(email: @email, user_id: @user.id, primary: false)
      end

      render json: success_json
    rescue => e
      render json: { error: e.message }, status: 422
    end
  end
end
