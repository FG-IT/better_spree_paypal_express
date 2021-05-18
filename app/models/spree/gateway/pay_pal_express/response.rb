module Spree
  class Gateway
    class PayPalExpress
      class Response
        attr_reader :params, :message, :test, :authorization, :avs_result, :cvv_result, :error_code, :emv_authorization, :network_transaction_id

        def success?
          @success
        end

        def test?
          @test
        end

        def fraud_review?
          @fraud_review
        end

        def initialize(success, message, params = {}, options = {})
          @success, @message, @params = success, message, params

          @test = options[:test] || false
          @authorization = params[:id]
          @fraud_review = nil
          @error_code = params[:trace_number]
          @emv_authorization = params[:emv_authorization]
          @network_transaction_id = params[:network_transaction_id]
          @avs_result = if params[:avs_result].kind_of?(::ActiveMerchant::Billing::AVSResult)
                          params[:avs_result].to_hash
                        else
                          ::ActiveMerchant::Billing::AVSResult.new(params[:avs_result]).to_hash
                        end

          @cvv_result = if params[:cvv_result].kind_of?(::ActiveMerchant::Billing::CVVResult)
                          params[:cvv_result].to_hash
                        else
                          ::ActiveMerchant::Billing::CVVResult.new(params[:cvv_result]).to_hash
                        end
        end


        def to_s
          "#{@message} #{@fraud_review}"
        end
      end
    end
  end
end

