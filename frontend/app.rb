# Início das dependências
require "sinatra"
require "json"
require "net/http"
require "uri"
# Fim das dependências

# Início das configurações do sinatra
set :port, 3000
set :bind, '0.0.0.0'
disable :protection
set :host_authorization, { permitted_hosts: [] }

configure do
  disable :protection
  set :host_authorization, { permitted_hosts: [] }
end

# ===============================
# FRONTEND - Interface Simples
# ===============================
# Exibe um botão para solicitar relatório e uma lista de notificações de progresso.

$user = "demo_user" # Usuário fixo para a demo
$notifications = [] # Armazena notificações recebidas

get "/" do
  <<-HTML
  <!doctype html>
  <html>
  <head>
    <meta charset="utf-8">
    <title>FRONTEND - Observer Demo</title>
    <style>
      body { font-family: sans-serif; background: #f7f7f7; margin: 0; padding: 2em; }
      .container { background: #fff; border-radius: 8px; box-shadow: 0 2px 8px #0001; padding: 2em; max-width: 600px; margin: auto; }
      button { padding: 0.5em 1.5em; font-size: 1em; border-radius: 4px; border: none; background: #007bff; color: #fff; cursor: pointer; }
      button:active { background: #0056b3; }
      .notif { margin: 1em 0; padding: 1em; border-radius: 6px; background: #e9ecef; }
      .started { border-left: 5px solid #007bff; }
      .progress { border-left: 5px solid #ffc107; }
      .finished { border-left: 5px solid #28a745; }
      #notif-btn { position: relative; background: none; border: none; font-size: 24px; cursor: pointer; }
      .badge { position: absolute; top: 10px; background: red; color: white; border-radius: 50%; padding: 2px 6px; font-size: 0px; width: 8px; height: 8px; text-align: center; }
      .header { position: relative; display: flex; flex: 1; flex-direction: row; justify-content: space-between; }
      #notifs { display: none; position: absolute; top: 50px; right: 0; background: #FFFFAA; padding-right: 1em; padding-left: 1em; }
      #spy_select { display: none; }
      .user { display: flex; flex-direction: row; align-items: center; gap: 0.5em; }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <div class="user">
          <label for="user_select">Usuário autenticado:</label>
          <select id="user_select" defaultValue="none">
            <option value="none" selected>Nenhum</option>
            <option value="João">João</option>
            <option value="Maria">Maria</option>
            <option value="Guilhermo">Guilhermo</option>
          </select>
        </div>


        <button id="notif-btn" onclick="toggleNotifications()">🔔 <span id="badge" class="badge"></span></button>
        <div id="notifs" style="display:none;"></div>
      </div>

      <label for="event_select">Receber notificações de:</label><br>
      <select id="event_select" multiple style="padding:0.5em; margin-bottom:1em; width:60%">
        <option value="report.started" selected>Início</option>
        <option value="report.progress" selected>Progresso</option>
        <option value="report.finished" selected>Finalização</option>
      </select>
      <br>
      <div id="phone_input" style="display:none;">
        <input type="text" id="phone">
      </div>

      <h2>Gerar PDF de Relatório </h2>

      <label for="spy_select">Marcar cerrado o usuário:</label>
      <select id="spy_select" style="padding:0.5em; margin-bottom:1em;" defaultValue="none">
        <option value="none" selected>Nenhum</option>
        <option value="João">João</option>
        <option value="Maria">Maria</option>
      </select>
      <br>
      <select id="report_name" style="padding:0.5em; width:60%">
        <option value="Consolidado" selected>Consolidado</option>
        <option value="Comparativo">Comparativo</option>
        <option value="Evolução">Evolução</option>
        <option value="Individual">Individual</option>
      </select>
      <button onclick="generate()">Gerar PDF</button>
      <p id="status"></p>
    </div>
    <script>
      let lastReportId = null;
      let clientId = sessionStorage.getItem('client_id') || (Math.random().toString(36).substring(2) + Date.now());

      sessionStorage.setItem('client_id', clientId);

      function getSelectedUser() {
        return document.getElementById('user_select').value;
      }

      function getSpyUser() {
        return document.getElementById('spy_select').value;
      }

      function getSelectedEvents() {
        return Array.from(document.getElementById('event_select').selectedOptions).map(o => o.value);
      }

      async function generate() {
        const name = document.getElementById('report_name').value || 'relatorio_demo';
        const user = getSelectedUser();
        console.log("ETAPA 1️⃣ - FRONTEND SOLICITA PDF AO BACKEND (user: " + user + ", report: " + name + ")");
        const resp = await fetch('/generate', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ report_name: name, user })
        });
        const data = await resp.json();
        lastReportId = data.report_id;
        document.getElementById('status').innerText = 'Solicitação enviada!';
      }

      // WebSocket para notificações em tempo real
      let ws = null;
      let wsNotifs = [];
      let hasUnread = false;

      function connectWebSocket() {
        let wsUrl = (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.hostname + ':4000/ws';
        ws = new WebSocket(wsUrl);
        ws.onopen = function() {
          // Envia o usuário autenticado e o canal espiado
          const user = getSelectedUser();
          let spy = getSpyUser();
          if (spy === 'none') spy = null;
          let phone = null;
          if (user === 'Guilhermo') {
            phone = document.getElementById('phone').value.trim();
            if (phone === '') phone = null;
          }
          ws.send(JSON.stringify({ user: user, spy: spy, phone: phone, events: getSelectedEvents() }));
          console.log('WebSocket conectado. user:', user, 'spy:', spy, 'phone:', phone, 'events:', getSelectedEvents());
        };
        ws.onmessage = function(event) {
          try {
            const n = JSON.parse(event.data);
            console.log('Recebido via WS:', n);
            console.log("ETAPA 1️⃣0️⃣ - FRONTEND RECEBE NOTIFICAÇÃO VIA WS E ATUALIZA UI (event: " + n.event + ")");
            if (n && n.event && n.data) {
              wsNotifs.push(n);
              hasUnread = true;
              renderAllNotifs();
            }
          } catch (e) { console.error('Erro ao processar mensagem WS', e); }
        };
        ws.onclose = function() {
          console.log('WebSocket desconectado, tentando reconectar em 2s...');
          setTimeout(connectWebSocket, 2000);
        };
      }

      function renderAllNotifs() {
        const byReport = {};

        wsNotifs.forEach(n => {
          const key = n.data.report_id || n.data.report_name;
          if (!key) return;
          byReport[key] = n;
        });
        
        document.getElementById('notifs').innerHTML = Object.values(byReport).map(n => renderNotifStatus(n)).join('');
        updateBadge(byReport);
      }

      function updateBadge(byReport) {
        const badge = document.getElementById('badge');
        if (hasUnread) {
          badge.textContent = "!";
          badge.style.display = 'inline';
        } else {
          badge.textContent = "";
          badge.style.display = 'none';
        }
      }

      function toggleSpySelect() {
        const user = getSelectedUser();
        const spySelect = document.getElementById('spy_select');
        const spyLabel = document.querySelector('label[for="spy_select"]');
        const spyBr = spyLabel.nextElementSibling; // o <br>
        if (user === 'Guilhermo') {
          spySelect.style.display = 'inline-block';
          spyLabel.style.display = 'inline';
          spyBr.style.display = 'block';
        } else {
          spySelect.style.display = 'none';
          spyLabel.style.display = 'none';
          spyBr.style.display = 'none';
        }
      }

      function togglePhoneInput() {
        const user = getSelectedUser();
        const phoneDiv = document.getElementById('phone_input');
        if (user === 'Guilhermo') {
          phoneDiv.style.display = 'block';
        } else {
          phoneDiv.style.display = 'none';
        }
      }

      function toggleNotifications() {
        const notifs = document.getElementById('notifs');
        const wasHidden = notifs.style.display === 'none';
        notifs.style.display = wasHidden ? 'block' : 'none';
        if (wasHidden) {
          hasUnread = false;
          updateBadge({});
        }
      }

      // Renderiza a notificação de acordo com o status mais recente
      function renderNotifStatus(n) {
        let tipo = '';
        let msg = '';
        const reportName = n.data && n.data.report_name ? n.data.report_name : '';
        const user = n.data && n.data.user ? n.data.user : '';
        if (n.event === 'report.started') {
          tipo = 'started';
          msg = `PDF iniciado: <b>${reportName}</b> <br>Usuário: <b>${user}</b>`;
        } else if (n.event === 'report.progress') {
          tipo = 'progress';
          msg = `Relatório: <b>${reportName}</b> <br>Usuário: <b>${user}</b><br><div style="width: 100%; background: #ddd; height: 20px; border-radius: 4px;"><div style="width: ${n.data.percent}%; background: #007bff; height: 100%; border-radius: 4px;"></div></div>`;
        } else if (n.event === 'report.finished') {
          tipo = 'finished';
          msg = `<b>PDF pronto!</b> <br>Relatório: <b>${reportName}</b> <br>Usuário: <b>${user}</b><br><a href="${n.data.pdf_url}" target="_blank">Baixar PDF</a>`;
        }
        return `<div class='notif ${tipo}'>${msg}<br><small>${n.at ? n.at : ''}</small></div>`;
      }

      function renderNotif(n) {
        let tipo = '';
        if (n.event === 'report.started') tipo = 'started';
        else if (n.event === 'report.progress') tipo = 'progress';
        else if (n.event === 'report.finished') tipo = 'finished';
        let msg = '';
        if (n.event === 'report.started') msg = `PDF iniciado: <b>${n.data.report_name || ''}</b>`;
        if (n.event === 'report.progress') msg = `Progresso: <b>${n.data.percent}%</b>`;
        if (n.event === 'report.finished') msg = `<b>PDF pronto!<a href="/pdf">baixar</a></b>`;
        return `<div class='notif ${tipo}'>${msg}<br><small>${n.at ? n.at : ''}</small></div>`;
      }

      window.onload = () => {
        updateBadge({});
        toggleSpySelect();
        togglePhoneInput();
        connectWebSocket();
        document.getElementById('user_select').addEventListener('change', () => {
          toggleSpySelect();
          togglePhoneInput();
          wsNotifs = [];
          hasUnread = false;
          document.getElementById('notifs').innerHTML = '';
          updateBadge({});
          if (ws) { ws.close(); }
          setTimeout(connectWebSocket, 100);
        });
        document.getElementById('spy_select').addEventListener('change', () => {
          wsNotifs = [];
          hasUnread = false;
          document.getElementById('notifs').innerHTML = '';
          updateBadge({});
          if (ws) { ws.close(); }
          setTimeout(connectWebSocket, 100);
        });
      };
    </script>
  </body>
  </html>
  HTML
end

get "/pdf" do
  <<-HTML
  <!doctype html>
  <html>
  <head>
    <meta charset="utf-8">
    <title>FRONTEND - Observer Demo</title>
    <style>
      body { font-family: sans-serif; background: #f7f7f7; margin: 0; padding: 2em; }
      .container { background: #fff; border-radius: 8px; box-shadow: 0 2px 8px #0001; padding: 2em; max-width: 600px; margin: auto; }
    </style>
  </head>
  <body>
    <div class="container">
    <p>Toma aí seu pdf</p>
    <img src="https://cdn-icons-png.flaticon.com/512/4726/4726010.png" width="256px" height="256px">
    </div>
  </body>
  </html>
  HTML
end

# Endpoint para solicitar relatório ao backend
post "/generate" do
  body = JSON.parse(request.body.read) rescue {}
  report_name = body["report_name"] || "relatorio_demo"
  user = body["user"] || $user
  puts "ETAPA 1️⃣ - FRONTEND SOLICITA PDF AO BACKEND (user: #{user}, report: #{report_name})"
  # Solicita ao backend
  uri = URI(ENV.fetch("BACKEND_URL", "http://backend:3001/generate"))
  payload = { report_name: report_name, user: user }

  begin
    res = Net::HTTP.post(uri, payload.to_json, "Content-Type" => "application/json")
    data = JSON.parse(res.body) rescue { report_id: nil }
    status 200
    { status: "requested", report_id: data["report_id"] }.to_json
  rescue => e
    status 500
    { error: "Falha ao solicitar backend: #{e.message}" }.to_json
  end
end

