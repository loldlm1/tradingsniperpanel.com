require "rails_helper"

RSpec.describe "Dashboard shared UI partials", type: :view do
  it "renders badge content with the provided classes" do
    render partial: "dashboard/shared/badge",
           locals: { label: "Muted", class_name: "bg-gray-100 text-gray-700" }

    expect(rendered).to include("Muted")
    expect(rendered).to include("bg-gray-100")
    expect(rendered).to include("text-gray-700")
  end

  it "renders filter chips as links" do
    render partial: "dashboard/shared/filter_chip", locals: { label: "Modules" }

    expect(rendered).to include("Modules")
    expect(rendered).to include('href="#"')
    expect(rendered).to include("rounded-full")
  end

  it "renders secondary buttons with the Mosaic class stack" do
    render partial: "dashboard/shared/secondary_button",
           locals: { label: "Back", href: "/dashboard/marketplace" }

    expect(rendered).to include('href="/dashboard/marketplace"')
    expect(rendered).to include("dark:bg-gray-800")
    expect(rendered).to include("dark:text-gray-300")
  end

  it "wraps table headers with Mosaic header styles" do
    render inline: <<~ERB
      <%= render("dashboard/shared/table_head") do %>
        <tr><th>Header</th></tr>
      <% end %>
    ERB

    expect(rendered).to include("bg-gray-50")
    expect(rendered).to include("dark:bg-gray-700/50")
    expect(rendered).to include("Header")
  end
end
