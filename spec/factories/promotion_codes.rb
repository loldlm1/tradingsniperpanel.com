FactoryBot.define do
  factory :promotion_code do
    sequence(:code) { |n| "SPRING#{n}" }
    percent_off { 15 }
    active { false }
    title_en { "Unlock #{percent_off}% off today" }
    title_es { "Desbloquea #{percent_off}% de descuento hoy" }
    body_en { "Use this promotion code during Stripe checkout for your next order." }
    body_es { "Usa este código promocional durante el checkout de Stripe en tu próxima orden." }
    cta_label_en { "View plans" }
    cta_label_es { "Ver planes" }
    stripe_coupon_id { "coupon_#{code.downcase}" }
    stripe_promotion_code_id { "promo_#{code.downcase}" }

    trait :active do
      active { true }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :archived do
      archived_at { Time.current }
      active { false }
    end
  end
end
