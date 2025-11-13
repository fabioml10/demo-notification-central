# Dependências principais
require "sinatra"      # Web server
require "json"         # Manipulação de JSON
require "faye/websocket" # Suporte a WebSocket
require "thread"       # (útil para concorrência)

# Observer para SMS (Twilio)
require_relative "observer/sms_observer"
TWILIO_SID = ENV['TWILIO_SID']
TWILIO_TOKEN = ENV['TWILIO_TOKEN']
TWILIO_FROM = ENV['TWILIO_FROM']

# Configuração básica do servidor Sinatra
set :bind, "0.0.0.0"
set :port, 4000
disable :protection
set :host_authorization, { permitted_hosts: [] }

configure do
  disable :protection
  set :host_authorization, { permitted_hosts: [] }
end

# ===============================
# CENTRAL DE NOTIFICAÇÕES (Observer Pattern)
# ===============================
# Aqui é onde tudo acontece: recebemos eventos do backend e notificamos todos os "observadores" (frontends conectados via WebSocket).

# Carrega as classes do Observer Pattern
require_relative "observer/event_subject"
require_relative "observer/websocket_observer"

# Cria o "sujeito" dos eventos: ele gerencia quem está observando cada tipo de evento
EVENT_SUBJECT = EventSubject.new

# Lista de eventos recebidos (apenas para consulta, não é usada no fluxo principal)
$events = []

# === RECEBE EVENTOS DO BACKEND ===
# O backend envia eventos para cá (ex: "relatório começou", "progresso", "terminou").
# A central publica para todos os observers conectados.
post "/publish" do
  body = JSON.parse(request.body.read) rescue {}
  event = body["event"]
  data  = body["data"]
  halt 400, { error: "evento não encontrado" }.to_json unless event
  puts "[Central] publicar: #{event} => #{data.inspect}"
  puts "ETAPA 6️⃣+ - CENTRAL RECEBE EVENTO #{event} E PUBLICA PARA OBSERVERS"
  $events << { at: Time.now.to_s, event: event, data: data }
  # Aqui acontece a mágica: todos os observers inscritos para esse evento recebem a notificação!
  EVENT_SUBJECT.publish(event, data)
  content_type :json
  { status: "publicado", event: event }.to_json
end

# === CONEXÃO WEBSOCKET (FRONTEND) ===
# Cada vez que um frontend se conecta, ele vira um "observer" dos eventos.
# O frontend informa qual usuário ele é e, opcionalmente, de quem quer "espionar" as notificações.
get '/ws' do
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)
    observer = nil
    eventos_inscritos = nil

    ws.on :open do |event|
      puts "WebSocket aberto: #{ws.object_id} (aguardando identificação do usuário)"
    end

    ws.on :message do |event|
      begin
        msg = JSON.parse(event.data) rescue nil

        if msg && msg["user"]
          user = msg["user"]
          spy = msg["spy"]
          eventos = msg["events"] || %w[report.started report.progress report.finished]
          eventos = ['report.finished'] if spy
          eventos_inscritos = eventos
          # Remove observer antigo (se já existia)
          if observer
            eventos_inscritos.each { |evt| EVENT_SUBJECT.unsubscribe(evt, observer) } if eventos_inscritos
            observer.close
          end
          # Cria um observer para este WebSocket, que só recebe eventos do próprio user ou do "espionado"
          observer = WebSocketObserver.new(ws, user, spy)
          # Inscreve nos eventos selecionados
          eventos.each { |evt| EVENT_SUBJECT.subscribe(evt, observer) }
          puts "WebSocket #{ws.object_id} identificado como user='#{user}', spy='#{spy}' (Observer registrado para eventos: #{eventos.join(', ')})"
        end

        if msg["phone"] && !msg["phone"].empty? && TWILIO_SID && TWILIO_TOKEN && TWILIO_FROM
          sms_observer = SmsObserver.new(TWILIO_SID, TWILIO_TOKEN, TWILIO_FROM, msg["phone"])
          EVENT_SUBJECT.subscribe('report.finished', sms_observer)
        end
      rescue => e
        puts "Erro ao processar mensagem inicial do WebSocket: #{e}"
      end
    end

    ws.on :close do |event|
      if observer
        eventos_inscritos.each { |evt| EVENT_SUBJECT.unsubscribe(evt, observer) } if eventos_inscritos
        observer.close
      end

      puts "WebSocket fechado: #{ws.object_id} (Observer removido)"
    end

    ws.rack_response
  else
    status 426
    body 'WebSocket required'
  end
end
