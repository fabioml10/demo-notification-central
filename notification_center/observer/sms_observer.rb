# Observer que envia notificações via SMS usando Twilio
require_relative 'observer'
require 'twilio-ruby'

class SmsObserver < Observer
  def initialize(account_sid, auth_token, from_number, to_number)
    @client = Twilio::REST::Client.new(account_sid, auth_token)
    @from = from_number
    @to = to_number
  end

  def update(event, data)
    msg = "[#{event}] Relatório: #{data['report_name']} (#{data['user']})"
    puts "ETAPA 9️⃣ - CENTRAL SMS OBSERVER ENVIA SMS (event: #{event}, user: #{data['user']})"

    begin
      @client.messages.create(
        from: @from,
        to: @to,
        body: msg
      )
      puts "[SmsObserver] SMS enviado para #{@to}: #{msg}"
    rescue => e
      puts "[SmsObserver] Falha ao enviar SMS: #{e}"
    end
  end
end
