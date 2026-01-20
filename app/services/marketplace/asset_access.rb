module Marketplace
  class AssetAccess
    Result = Struct.new(:allowed, :reason, :asset, keyword_init: true) do
      def allowed?
        !!allowed
      end
    end

    def initialize(user:, asset:)
      @user = user
      @asset = asset
    end

    def call
      return Result.new(allowed: false, reason: :missing_user, asset: asset) unless user
      return Result.new(allowed: false, reason: :missing_asset, asset: asset) unless asset

      allowed = MarketplacePurchase
                .joins(billing_plan: :marketplace_assets)
                .where(user: user, marketplace_assets: { id: asset.id })
                .exists?
      return Result.new(allowed: true, asset: asset) if allowed

      Result.new(allowed: false, reason: :not_purchased, asset: asset)
    end

    private

    attr_reader :user, :asset
  end
end
