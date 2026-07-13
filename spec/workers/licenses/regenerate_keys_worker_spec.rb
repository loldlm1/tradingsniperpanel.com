require "rails_helper"

RSpec.describe Licenses::RegenerateKeysWorker do
  it "does not rotate tokens from legacy queued jobs" do
    license = create(:license)

    expect { described_class.new.perform }.not_to change { license.reload.token_version }
  end
end
