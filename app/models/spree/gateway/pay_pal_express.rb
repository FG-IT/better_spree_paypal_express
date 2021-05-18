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
    preference :no_shipping, :integer, default: 0

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

    def capture(credit_cents, transaction_id, _gateway_options)

      payment_id = _gateway_options[:order_id].split('-')[-1]
      payment = Spree::Payment.find_by(number: payment_id)
      transaction_id = payment.source.transaction_id
      params = {
          :AuthorizationID => transaction_id,
          :CompleteType => "Complete",
          :Amount => {
              :currencyID => _gateway_options[:currency],
              :value => credit_cents.to_f / 100}
      }

      logger.info params

      do_capture = provider.build_do_capture(params)
      pp_response = provider.do_capture(do_capture)


      if pp_response.success?
        Spree::PaypalExpressCheckout.find_by(transaction_id: transaction_id).update(state: 'completed')

        begin
          transaction_id = pp_response.do_capture_response_details.payment_info.first.transaction_id
        rescue
          transaction_id = pp_response.do_capture_response_details.payment_info.transaction_id
        end
        logger.info transaction_id

        Spree::PaypalExpressCheckout.find_by(transaction_id: transaction_id).update(state: 'completed', transaction_id: transaction_id)

        Response.new(true, nil, {:id => transaction_id})
      else
        class << pp_response
          def to_s
            errors.map(&:long_message).join(" ")
          end
        end

        pp_response
      end
    end


    def credit(credit_cents, transaction_id, _options)
      payment = _options[:originator].payment
      refund(transaction_id, payment, credit_cents)
    end

    def cancel(response_code, _source, payment)
      if response_code.nil?
        source = _source
      else
        source = Spree::PaypalExpressCheckout.find_by(token: response_code)
      end

      if payment.present? and source.can_credit? payment
        refund(nil, payment, payment.money.amount_in_cents)
      else
        void(source.transaction_id, source, nil)
      end
    end

    def void(response_code, _source, gateway_options)

      if _source.present?
        source = _source
      else
        source = Spree::PaypalExpressCheckout.find_by(token: response_code)
      end

      void_transaction = provider.build_do_void({
                                                    :AuthorizationID => source.transaction_id
                                                })

      do_void_response = provider.do_void(void_transaction)


      if do_void_response.success?
        Spree::PaypalExpressCheckout.find_by(transaction_id: source.transaction_id).update(state: 'voided')
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
        class << do_void_response
          def to_s
            errors.map(&:long_message).join(" ")
          end
        end

        do_void_response
      end
    end

    def refund(transaction_id, payment, credit_cents)
      unless transaction_id.present?
        transaction_id = payment.source.transaction_id
      end

      refund_type = payment.money.amount_in_cents == credit_cents ? "Full" : "Partial"
      params = {
          :TransactionID => transaction_id,
          :RefundType => refund_type,
          :Amount => {
              :currencyID => payment.currency,
              :value => credit_cents.to_f / 100},
          :RefundSource => "any"}
      logger.info params

      refund_transaction = provider.build_refund_transaction(params)
      refund_transaction_response = provider.refund_transaction(refund_transaction)
      if refund_transaction_response.success?
        payment.source.update({
                                  :refunded_at => Time.now,
                                  :refund_transaction_id => refund_transaction_response.RefundTransactionID,
                                  :state => "refunded",
                                  :refund_type => refund_type
                              })
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
        begin
          transaction_id = pp_response.do_express_checkout_payment_response_details.payment_info.first.transaction_id
        rescue
          transaction_id = pp_response.do_express_checkout_payment_response_details.payment_info.transaction_id
        end

        express_checkout.update_column(:transaction_id, transaction_id)

        Response.new(true, nil, {:id => transaction_id})

      else
        class << pp_response
          def to_s
            errors.map(&:long_message).join(" ")
          end
        end

        Response.new(false, pp_response, nil)

      end
    end
  end
end
