require "rails_helper"

RSpec.describe MarkdownRenderer do
  describe ".render" do
    it "embeds local video tokens as inline video" do
      allow(described_class).to receive(:resolve_asset_url).and_return("/assets/docs/videos/video.mp4")

      html = described_class.render("Intro\n\n[[video:docs/videos/video.mp4]]\n")

      expect(html).to include("data-guide-embed=\"video\"")
      expect(html).to include("src=\"/assets/docs/videos/video.mp4\"")
      expect(html).to include("autoplay")
      expect(html).to include("muted")
    end

    it "embeds youtube tokens as iframes" do
      html = described_class.render("[[youtube:https://www.youtube.com/watch?v=dQw4w9WgXcQ]]")

      expect(html).to include("youtube.com/embed/dQw4w9WgXcQ")
      expect(html).to include("data-guide-embed=\"youtube\"")
      expect(html).to include("autoplay=1")
    end

    it "does not replace tokens inside code fences" do
      markdown = "```\n[[video:docs/videos/video.mp4]]\n```"
      html = described_class.render(markdown)

      expect(html).to include("[[video:docs/videos/video.mp4]]")
      expect(html).not_to include("data-guide-embed=\"video\"")
    end
  end
end
