require "zlib"

module Dashboard
  class BrokerAnalyticsPresenter
    SetupRow = Struct.new(:ea_name, :broker_name, :account_type, :pnl_7d_cents, :win_rate, :last_synced_at, keyword_init: true)
    BrokerCard = Struct.new(:title, :ea_name, :account_type, :pnl_cents, :status, :identifier, keyword_init: true)

    attr_reader :totals, :chart_points, :setups, :pagination, :broker_cards, :tiles

    def initialize(user:, page: 1, per_page: 10)
      @user = user
      @page = [page.to_i, 1].max
      @per_page = per_page
    end

    def call
      accounts = broker_accounts.to_a
      @totals = build_totals(accounts)
      @chart_points = build_chart_points(accounts)
      @setups = paginate(build_setup_rows(accounts))
      @broker_cards = build_broker_cards(accounts)
      @tiles = build_tiles
      self
    end

    private

    attr_reader :user, :page, :per_page

    def broker_accounts
      return BrokerAccount.none unless user

      BrokerAccount.joins(license: :expert_advisor)
                   .includes(license: :expert_advisor)
                   .where(licenses: { user_id: user.id })
    end

    def build_totals(accounts)
      {
        total: accounts.count,
        real: accounts.count { |acc| acc.account_type == "real" },
        demo: accounts.count { |acc| acc.account_type == "demo" }
      }
    end

    def build_tiles
      average_daily = avg_daily_pnl_cents(chart_points)
      {
        average_daily_pnl_cents: average_daily
      }
    end

    def build_chart_points(accounts)
      base = 150_00 + accounts.count * 25_00
      points = (0..6).map do |index|
        shift = (index - 3) * 12_00
        { label: (Date.current - (6 - index).days), amount_cents: base + shift }
      end

      points
    end

    def build_setup_rows(accounts)
      rows = accounts.map do |account|
        seed = account.id || account.account_number.to_s
        SetupRow.new(
          ea_name: account.license&.expert_advisor&.name || I18n.t("dashboard.analytics.unknown_ea"),
          broker_name: account.company,
          account_type: account.account_type,
          pnl_7d_cents: sample_pnl_cents(seed),
          win_rate: sample_win_rate(seed),
          last_synced_at: sample_sync_time(seed)
        )
      end

      return rows unless rows.empty?

      sample_fallback_rows
    end

    def paginate(rows)
      total_pages = (rows.count / per_page.to_f).ceil
      total_pages = 1 if total_pages.zero?
      current_page = [page, total_pages].min

      sliced = rows.slice((current_page - 1) * per_page, per_page) || []
      @pagination = {
        current_page: current_page,
        total_pages: total_pages,
        total_count: rows.count
      }

      sliced
    end

    def build_broker_cards(accounts)
      cards = accounts.map do |account|
        BrokerCard.new(
          title: account.company.presence || I18n.t("dashboard.broker_accounts.unnamed"),
          ea_name: account.license&.expert_advisor&.name,
          account_type: account.account_type,
          pnl_cents: sample_pnl_cents(account.id || account.account_number.to_s),
          status: account.license&.status || "active",
          identifier: account.account_number
        )
      end

      return cards unless cards.empty?

      sample_fallback_cards
    end

    def sample_pnl_cents(seed)
      raw = (Zlib.crc32(seed.to_s) % 800) - 400
      raw * 100
    end

    def sample_win_rate(seed)
      50 + (Zlib.crc32(seed.to_s) % 25)
    end

    def sample_sync_time(seed)
      Time.current - (Zlib.crc32(seed.to_s) % 36).hours
    end

    def sample_fallback_rows
      [
        SetupRow.new(
          ea_name: I18n.t("dashboard.analytics.sample_ea"),
          broker_name: "Apex FX",
          account_type: "real",
          pnl_7d_cents: 124_50,
          win_rate: 62,
          last_synced_at: 2.hours.ago
        ),
        SetupRow.new(
          ea_name: I18n.t("dashboard.analytics.sample_ea_alt"),
          broker_name: "Fusion Markets",
          account_type: "demo",
          pnl_7d_cents: -23_75,
          win_rate: 55,
          last_synced_at: 5.hours.ago
        )
      ]
    end

    def sample_fallback_cards
      [
        BrokerCard.new(
          title: "Apex FX #20145",
          ea_name: I18n.t("dashboard.analytics.sample_ea"),
          account_type: "real",
          pnl_cents: 124_50,
          status: "active",
          identifier: "20145"
        ),
        BrokerCard.new(
          title: "Demo Lab #8302",
          ea_name: I18n.t("dashboard.analytics.sample_ea_alt"),
          account_type: "demo",
          pnl_cents: -23_75,
          status: "trial",
          identifier: "8302"
        )
      ]
    end

    def avg_daily_pnl_cents(points)
      return 0 if points.empty?

      (points.sum { |point| point[:amount_cents].to_i } / points.size.to_f).round
    end
  end
end
