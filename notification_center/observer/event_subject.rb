# Subject especializado para eventos da central de notificações
require_relative "observer"

class EventSubject
  def initialize
    super
    @event_observers = Hash.new { |h, k| h[k] = [] }
  end

  # Permite inscrever observer para um evento específico
  def subscribe(event, observer)
    @event_observers[event] << observer
  end

  # Remove observer de um evento específico
  def unsubscribe(event, observer)
    @event_observers[event].delete(observer)
  end

  # Notifica apenas observers do evento
  def publish(event, data)
    puts "ETAPA 7️⃣+ - CENTRAL SUBJECT PUBLICA PARA OBSERVERS DO EVENTO #{event}"
    (@event_observers[event] || []).each do |observer|
      observer.update(event, data)
    end
  end
end
