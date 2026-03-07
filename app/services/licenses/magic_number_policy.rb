require "securerandom"

module Licenses
  module MagicNumberPolicy
    MIN_VALUE = 1
    MAX_VALUE = 2_147_483_647

    module_function

    def supported?(value)
      integer = Integer(value.to_s, 10)
      integer.between?(MIN_VALUE, MAX_VALUE)
    rescue ArgumentError, TypeError
      false
    end

    def generate
      SecureRandom.random_number(MAX_VALUE - MIN_VALUE + 1) + MIN_VALUE
    end
  end
end
