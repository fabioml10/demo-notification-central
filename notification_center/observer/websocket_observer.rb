# Observer que envia notificações via WebSocket para o frontend
require_relative 'observer'

class WebSocketObserver < Observer
  attr_reader :ws, :user, :spy

  def initialize(ws, user, spy)
    @ws = ws
    @user = user
    @spy = spy
    @closed = false
  end

  def update(event, data)
    return if @closed
    event_user = data["user"]
    puts "ETAPA 8️⃣ - CENTRAL WEBSOCKET OBSERVER ENVIA NOTIFICAÇÃO PARA FRONTEND VIA WS (event: #{event}, user: #{event_user})"
    # Envia se for do próprio user ou do canal espiado
    if event_user && (
      @user == event_user ||
      (!@spy.nil? && @spy == event_user)
    )
      begin
        @ws.send({ event: event, data: data }.to_json)
      rescue => e
        puts "[WebSocketObserver] Erro ao enviar: #{e}"
      end
    end
  end

  def close
    @closed = true
  end
end
