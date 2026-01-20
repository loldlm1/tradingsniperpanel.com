module StripeHelpers
  def with_stripe_key
    previous = ENV["STRIPE_PRIVATE_KEY"]
    ENV["STRIPE_PRIVATE_KEY"] = "sk_test_admin"
    yield
  ensure
    ENV["STRIPE_PRIVATE_KEY"] = previous
  end

  def stub_stripe_product_and_price(
    product_id: "prod_admin",
    price_id: "price_admin",
    amount_cents: 4900,
    currency: "usd",
    recurring: nil
  )
    product = instance_double(
      Stripe::Product,
      id: product_id,
      name: "Admin Product",
      description: "",
      metadata: {}
    )
    price = instance_double(
      Stripe::Price,
      id: price_id,
      unit_amount: amount_cents,
      currency: currency,
      active: true,
      recurring: recurring
    )

    allow(Stripe::Product).to receive(:retrieve).and_return(product)
    allow(Stripe::Price).to receive(:retrieve).and_return(price)
    allow(Stripe::Product).to receive(:create).and_return(product)
    allow(Stripe::Price).to receive(:create).and_return(price)
    allow(Stripe::Product).to receive(:update).and_return(product)
    allow(Stripe::Price).to receive(:update).and_return(price)

    if Stripe::Product.respond_to?(:search)
      allow(Stripe::Product).to receive(:search).and_return(double(data: []))
    end
    if Stripe::Product.respond_to?(:list)
      allow(Stripe::Product).to receive(:list).and_return(double(data: []))
    end

    product
  end
end

RSpec.configure do |config|
  config.include StripeHelpers
end
