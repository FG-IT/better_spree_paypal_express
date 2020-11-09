//= require spree/frontend
var checkoutText = ''
SpreePaypalExpress = {
    updateSaveAndContinueVisibility: function () {
        if (this.isButtonHidden()) {
            $(this).trigger('hideSaveAndContinue')
        } else {
            $(this).trigger('showSaveAndContinue')
        }
    },
    isButtonHidden: function () {
        paymentMethod = this.checkedPaymentMethod();
        return (SpreePaypalExpress.paymentMethodID && paymentMethod.val() === SpreePaypalExpress.paymentMethodID);
    },
    checkedPaymentMethod: function () {
        return $('div[data-hook="checkout_payment_step"] input[type="radio"][name="order[payments_attributes][][payment_method_id]"]:checked');
    },
    hideSaveAndContinue: function () {
        if (checkoutText == '') {
            checkoutText = $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").val()
        }
        $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").html('Complete order');
        $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").val('Complete order');
    },
    showSaveAndContinue: function () {
        if (checkoutText != '') {
            $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").html(checkoutText);
            $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").val(checkoutText);
        }
    }
}

document.addEventListener('turbolinks:load', function () {
    SpreePaypalExpress.updateSaveAndContinueVisibility();
    paymentMethods = $('div[data-hook="checkout_payment_step"] input[type="radio"]').click(function (e) {
        SpreePaypalExpress.updateSaveAndContinueVisibility();
    });
    var paypal_logo_tag = $('#paypal-image-logo')
    $('div[data-hook="checkout_payment_step"] .payment-option').each(function () {
        var radio = $(this).find('input[type="radio"][name="order[payments_attributes][][payment_method_id]')
        if (radio.attr('value') == SpreePaypalExpress.paymentMethodID) {
            $(this).find('.spree-radio-label-text').html(paypal_logo_tag.html())
        }
    })
    $('#checkout_form_payment').submit(function () {
        $("#checkout_form_payment [data-hook=buttons] .checkout-content-save-continue-button").attr('disabled', 'disabled')
        var paymentMethod = SpreePaypalExpress.checkedPaymentMethod();
        if (SpreePaypalExpress.paymentMethodID && SpreePaypalExpress.paymentMethodID == paymentMethod.val()) {
            $("#paypal_button")[0].click();
            return false
        }
    })
})