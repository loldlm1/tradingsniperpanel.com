require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      head :ok
    end
  end

  around do |example|
    original = I18n.locale
    example.run
    I18n.locale = original
  end

  it "omits locale when using the default locale" do
    I18n.locale = I18n.default_locale
    get :index

    expect(controller.default_url_options).to eq({})
  end

  it "includes locale when non-default is set" do
    I18n.locale = :es
    get :index

    expect(controller.default_url_options).to eq({ locale: :es })
  end
end
