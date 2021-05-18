module Spree
  module PaymentDecorator
    def cancel!
      if payment_method.is_a?(Spree::Gateway::PayPalExpress)
        response = payment_method.cancel(response_code, source, self)
      else
        response = payment_method.cancel(response_code)
      end
      handle_response(response, :void, :failure)
    end

    def void_transaction!
      return true if void?

      protect_from_connection_error do
        if payment_method.payment_profiles_supported? or payment_method.is_a?(Spree::Gateway::PayPalExpress)
          # Gateways supporting payment profiles will need access to credit card object because this stores the payment profile information
          # so supply the authorization itself as well as the credit card, rather than just the authorization code
          response = payment_method.void(response_code, source, gateway_options)
        else
          # Standard ActiveMerchant void usage
          response = payment_method.void(response_code, gateway_options)
        end

        record_response(response)

        if response.success?
          self.response_code = response.authorization
          void
        else
          gateway_error(response)
        end
      end
    end
  end
end

Spree::Payment.prepend Spree::PaymentDecorator
