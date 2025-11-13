# Interface para observers (quem recebe notificações)
class Observer
  # Método chamado quando um evento ocorre
  # event: nome do evento (string)
  # data: dados do evento (hash)
  def update(event, data)
    raise NotImplementedError, "Observer deve implementar update"
  end
end
