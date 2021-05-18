module Spree
  class PaypalExpressCheckout < ActiveRecord::Base
    def actions
      %w(capture void credit)
    end

    def can_void?(payment)
      !payment.failed? && !payment.void? && !payment.completed?
    end

    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    def can_credit?(payment)
      payment.completed? && payment.credit_allowed > 0
    end

  end
end
