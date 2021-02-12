require 'paypal-sdk-merchant'
module Spree
  class Gateway::PayPalExpress < Gateway
    preference :login, :string
    preference :password, :string
    preference :signature, :string
    preference :server, :string, default: 'sandbox'
    preference :solution, :string, default: 'Mark'
    preference :landing_page, :string, default: 'Billing'
    preference :logourl, :string, default: ''
    preference :auto_capture, :integer, default: 0

    def supports?(source)
      true
    end

    def provider_class
      ::PayPal::SDK::Merchant::API
    end

    def provider
      ::PayPal::SDK.configure(
          :mode => preferred_server.present? ? preferred_server : "sandbox",
          :username => preferred_login,
          :password => preferred_password,
          :signature => preferred_signature,
          ssl_options: {ca_file: nil}
      )
      provider_class.new
    end

    def auto_capture?
      true
    end

    def method_type
      'paypal'
    end

    def authorize(amount, express_checkout, gateway_options = {})
      sale(amount, express_checkout, "Authorization", gateway_options)
    end

    def purchase(amount, express_checkout, gateway_options = {})
      sale(amount, express_checkout, "Sale", gateway_options)
    end

    def settle(amount, checkout, _gateway_options) end

    def capture(amount, transaction_id, _gateway_options)
      checkout = Spree::PaypalExpressCheckout.find_by(transaction_id: transaction_id)
      @do_capture = provider.build_do_capture({
                                                  :AuthorizationID => transaction_id,
                                                  :CompleteType => "Complete",
                                                  :Amount => {
                                                      :currencyID => payment.currency,
                                                      :value => amount},
                                                  :RefundSource => "any"})
      @do_capture_response = api.do_capture(@do_capture) if request.post?
    end

    def void(token, _data)

      source = Spree::PaypalExpressCheckout.find_by(token: token)
      transaction_id = source.transaction_id
      void_transaction = provider.build_do_void({
                                                    :AuthorizationID => transaction_id
                                                })

      do_void_response = provider.do_void(void_transaction)
      if do_void_response.success?
        Spree::PaypalExpressCheckout.find_by(transaction_id: transaction_id).update(state: 'voided')
      end
      do_void_response
    end

    def credit(credit_cents, transaction_id, _options)
      payment = _options[:originator].payment
      refund(payment, credit_cents.to_f / 100)
    end


    def refund(payment, amount)
      refund_type = payment.amount == amount.to_f ? "Full" : "Partial"
      refund_transaction = provider.build_refund_transaction({
                                                                 :TransactionID => payment.source.transaction_id,
                                                                 :RefundType => refund_type,
                                                                 :Amount => {
                                                                     :currencyID => payment.currency,
                                                                     :value => amount},
                                                                 :RefundSource => "any"})
      refund_transaction_response = provider.refund_transaction(refund_transaction)
      if refund_transaction_response.success?
        payment.source.update({
                                  :refunded_at => Time.now,
                                  :refund_transaction_id => refund_transaction_response.RefundTransactionID,
                                  :state => "refunded",
                                  :refund_type => refund_type
                              })

        payment.class.create!(
            :order => payment.order,
            :source => payment,
            :payment_method => payment.payment_method,
            :amount => amount.to_f.abs * -1,
            :response_code => refund_transaction_response.RefundTransactionID,
            :state => 'completed'
        )
      end
      refund_transaction_response
    end

    private

    def sale(amount, express_checkout, payment_action, gateway_options = {})
      pp_details_request = provider.build_get_express_checkout_details({
                                                                           :Token => express_checkout.token
                                                                       })
      pp_details_response = provider.get_express_checkout_details(pp_details_request)

      pp_request = provider.build_do_express_checkout_payment({
                                                                  :DoExpressCheckoutPaymentRequestDetails => {
                                                                      :PaymentAction => payment_action,
                                                                      :Token => express_checkout.token,
                                                                      :PayerID => express_checkout.payer_id,
                                                                      :PaymentDetails => pp_details_response.get_express_checkout_details_response_details.PaymentDetails
                                                                  }
                                                              })

      pp_response = provider.do_express_checkout_payment(pp_request)
      if pp_response.success?
        # We need to store the transaction id for the future.
        # This is mainly so we can use it later on to refund the payment if the user wishes.
        transaction_id = pp_response.do_express_checkout_payment_response_details.payment_info.first.transaction_id
        express_checkout.update_column(:transaction_id, transaction_id)
        # This is rather hackish, required for payment/processing handle_response code.
        Class.new do
          def success?
            true;
          end

          def authorization
            nil;
          end
        end.new
      else
        class << pp_response
          def to_s
            errors.map(&:long_message).join(" ")
          end
        end

        pp_response
      end
    end
  end
end
