require "rails_helper"

RSpec.describe "I18n translations" do
  it "supports the configured locales" do
    expect(I18n.available_locales.map(&:to_sym)).to include(:en, :es)
  end

  it "provides core copy for both locales" do
    %i[en es].each do |locale|
      expect { I18n.t!("app.name", locale:) }.not_to raise_error
      expect { I18n.t!("hero.title", locale:) }.not_to raise_error
      expect { I18n.t!("dashboard.courses.index.title", locale:) }.not_to raise_error
      expect { I18n.t!("dashboard.courses.unlock_cta", locale:) }.not_to raise_error
      expect { I18n.t!("dashboard.nav.courses", locale:) }.not_to raise_error
      expect { I18n.t!("dashboard.main.header.title", locale:) }.not_to raise_error
      expect { I18n.t!("dashboard.main.pnl_card.title", locale:) }.not_to raise_error
      expect { I18n.t!("dashboard.main.balance_card.title", locale:) }.not_to raise_error
      expect { I18n.t!("dashboard.main.account_summary.title", locale:) }.not_to raise_error
      expect { I18n.t!("active_admin.marketplace_products.sections.product", locale:) }.not_to raise_error
      expect { I18n.t!("active_admin.marketplace_assets.labels.marketplace_products", locale:) }.not_to raise_error
      expect { I18n.t!("active_admin.expert_advisors.bundle_coverage.complete", locale:) }.not_to raise_error
    end
  end
end
