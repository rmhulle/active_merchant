require 'test_helper'

class RemoteIuguTest < Test::Unit::TestCase
  def setup
    @gateway = IuguGateway.new(fixtures(:iugu))

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4012888888881881')
    @new_credit_card = credit_card('5555555555554444')

    @options = {
      test: true,
      email: 'test@test.com',
      ignore_due_email: true,
      due_date: 10.days.from_now,
      items: [{price_cents: 100, quantity: 1, description: 'ActiveMerchant Test Purchase'},
              {price_cents: 100, quantity: 2, description: 'ActiveMerchant Test Purchase'}],
      address: { email: 'test@test.com',
                 street: 'Street',
                 number: 1,
                 city: 'Test',
                 state: 'SP',
                 country: 'Brasil',
                 zip_code: '12122-0001' },
     payer: { name: 'Test Name',
              cpf_cnpj: "12312312312",
              phone_prefix: '11',
              phone: '12121212',
              email: 'test@test.com' }
    }

    @options_force_cc = @options.merge(payable_with: 'credit_card')
  end

  def test_successful_authorize_with_bank_slip
    assert response = @gateway.authorize(@amount, nil, @options)

    assert_success response

    assert response.authorization
    assert response.test
    assert response.message.blank?
    assert response.params['pdf']
    assert response.params['url']
    assert response.params['invoice_id']

    assert_equal response.authorization, response.params['invoice_id']
    assert_match(/iugu\.com/, response.params["url"])
    assert_match(/iugu\.com/, response.params["pdf"])
  end

  def test_successful_authorize_with_credit_card
    assert response = @gateway.authorize(@amount, @credit_card, @options_force_cc)

    assert_success response

    assert response.authorization
    assert response.test
    assert response.params['pdf']
    assert response.params['url']
    assert response.params['invoice_id']

    assert_equal response.message, 'Autorizado'
    assert_equal response.authorization, response.params['invoice_id']
    assert_match(/iugu\.com/, response.params["url"])
    assert_match(/iugu\.com/, response.params["pdf"])
  end

  def test_successful_capture_with_credit_card
    assert response = @gateway.authorize(@amount, @credit_card, @options_force_cc)
    assert response = @gateway.capture(@amount, response.authorization, {test: true})

    assert_success response

    assert response.params['id']
    assert response.params['email']
    assert response.authorization
    assert response.test
  end

  def test_successful_purchase_with_credit_card
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response

    assert response.authorization
    assert response.test

    assert_equal 'test@test.com', response.params['email']
    assert_equal 300, response.params["items_total_cents"]
    assert_equal 2, response.params["items"].size
    assert_equal response.authorization, response.params["id"]
    assert_match(/iugu\.com/, response.params["secure_url"])
  end

  def test_declined_authorize_with_credit_card
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert response.test
    assert_equal "Transação negada", response.message
  end

  def test_declined_purchase_with_credit_card
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert response.test
    assert_equal "Transação negada", response.message
  end
end
