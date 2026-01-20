if defined?(ActsAsTaggableOn::Tag)
  ActsAsTaggableOn::Tag.class_eval do
    def self.ransackable_associations(_auth_object = nil)
      []
    end

    def self.ransackable_attributes(_auth_object = nil)
      %w[created_at id name updated_at]
    end
  end
end
