tailwind_bin_dir = Rails.root.join("node_modules/.bin")
ENV["TAILWINDCSS_INSTALL_DIR"] ||= tailwind_bin_dir.to_s if Dir.exist?(tailwind_bin_dir)
