Deface::Override.new(
  virtual_path: "spree/orders/edit",
  name: "add_paypal_icon_to_cart_page_under_checkout_btn",
  insert_bottom: "[data-hook='cart_buttons']",
  partial: "spree/shared/paypal_icons.html.erb",
)
