module PayPal
  module RefundTransactionResponseTypeDecorator

    def authorization
      self.to_hash[:RefundTransactionID]
    end

    def params
      {:message => self.to_hash[:LongMessage]}
    end

    def message
      self.to_hash[:ShortMessage]
    end
  end
end

::PayPal::SDK::Merchant::DataTypes::RefundTransactionResponseType.prepend(PayPal::RefundTransactionResponseTypeDecorator)