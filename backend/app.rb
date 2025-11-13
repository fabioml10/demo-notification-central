# Início das dependências
require "sinatra"
require "json"
require "net/http"
require "uri"
# Fim das dependências

# início das configurações do sinatra
set :port, 3001
set :bind, '0.0.0.0'

disable :protection
set :host_authorization, { permitted_hosts: [] }

configure do
  disable :protection
  set :host_authorization, { permitted_hosts: [] }
end

# ===============================
# BACKEND - Serviço de Relatórios
# ===============================
# Este serviço recebe requisições para gerar relatórios, simula o processamento
# e envia eventos de progresso para a Central de Notificações.

# Endpoint para receber solicitação de geração de relatório
post "/generate" do
  # Lê o corpo da requisição (espera JSON com report_id e report_name)
  body = JSON.parse(request.body.read) rescue {}
  report_id = body["report_id"] || rand(1000..9999)
  report_name = body["report_name"] || "relatorio"
  user = body["user"] || "anon"

  puts "[BACKEND] Solicitação recebida para gerar relatório: id=#{report_id}, name=#{report_name}, user=#{user}"
  puts "ETAPA 2️⃣ - BACKEND RECEBE SOLICITAÇÃO (id: #{report_id})"

  # Inicia o processamento em uma thread para não bloquear a resposta HTTP
  Thread.new do
    sleep 1
    puts "ETAPA 3️⃣ - BACKEND NOTIFICA CENTRAL QUE PROCESSO COMEÇOU (id: #{report_id})"
    # Notifica início do processamento para a Central de Notificações
    notify_central("report.started", { report_id: report_id, report_name: report_name, user: user })
    sleep 3

    # Simula progresso do relatório
    1.upto(10) do |step|
      sleep 1 # Simula tempo de processamento
      percent = step * 10
      puts "ETAPA 4️⃣ - BACKEND NOTIFICA CENTRAL SOBRE PROGRESSO DO RELATÓRIO (id: #{report_id})"
      notify_central("report.progress", { report_id: report_id, report_name: report_name, user: user, percent: percent })
    end

    # Notifica conclusão
    puts "ETAPA 5️⃣ - BACKEND NOTIFICA CENTRAL QUE RELATÓRIO ESTÁ PRONTO (id: #{report_id})"
    notify_central("report.finished", { report_id: report_id, report_name: report_name, user: user, status: "ready", pdf_url: "/pdf?report_id=#{report_id}" })
    puts "[BACKEND] Relatório concluído: id=#{report_id}"
  end

  content_type :json
  { status: "processing", report_id: report_id }.to_json
end

# Função auxiliar para notificar a Central de Notificações
def notify_central(event, data)
  uri = URI(ENV.fetch("NOTIFICATION_CENTER_URL", "http://notification_center:4000/publish"))
  payload = { event: event, data: data }

  begin
    res = Net::HTTP.post(uri, payload.to_json, "Content-Type" => "application/json")
    puts "[BACKEND] Notificado: #{event} (status #{res.code})"
  rescue => e
    puts "[BACKEND] Falha ao notificar central: #{e.message}"
  end
end
