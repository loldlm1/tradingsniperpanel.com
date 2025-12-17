module Users
  class AccountSettingsUpdater
    Result = Struct.new(:success?, :password_changed?, keyword_init: true)

    def initialize(user:, params:)
      @user = user
      @params = params.to_h.symbolize_keys
    end

    def call
      password_change_requested? ? update_with_password : update_without_password
    end

    private

    attr_reader :user, :params

    def password_change_requested?
      params[:password].present? || params[:password_confirmation].present?
    end

    def update_without_password
      user.update(name: params[:name])
      Result.new(success?: user.errors.none?, password_changed?: false)
    end

    def update_with_password
      if params[:current_password].blank?
        user.errors.add(:current_password, :blank)
        return Result.new(success?: false, password_changed?: false)
      end

      unless user.valid_password?(params[:current_password])
        user.errors.add(:current_password, :invalid)
        return Result.new(success?: false, password_changed?: false)
      end

      success = user.update(
        name: params[:name],
        password: params[:password],
        password_confirmation: params[:password_confirmation]
      )

      Result.new(success?: success, password_changed?: success)
    end
  end
end

