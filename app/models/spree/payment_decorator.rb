module Spree
  module PaymentDecorator
    def cancel!
      if response_code.nil?
        response = payment_method.cancel(response_code, source, self)
      else
        response = payment_method.cancel(response_code)
      end
      handle_response(response, :void, :failure)
    end
  end
end

Spree::Payment.prepend Spree::PaymentDecorator
