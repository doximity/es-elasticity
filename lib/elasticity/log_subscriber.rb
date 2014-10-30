require "active_support/subscriber"
require "active_support/log_subscriber"

module Elasticity
  GRAY = "\e[90m"

  class LogSubscriber < ::ActiveSupport::LogSubscriber
    def index_create(event)
      log_event(event)
    end

    def index_delete(event)
      log_event(event)
    end

    def index_document(event)
      log_event(event)
    end

    def delete_document(event)
      log_event(event)
    end

    def get_document(event)
      log_event(event)
    end

    def search(event)
      log_event(event)
    end

    def delete_by_query(event)
      log_event(event)
    end

    def settings(event)
      log_event(event)
    end

    def mappings(event)
      log_event(event)
    end

    def flush(event)
      log_event(event)
    end

    def multi_search(event)
      log_event(event)
    end

    private

    def log_event(event)
      bt = event.payload[:backtrace]

      if bt.present? && defined?(Rails)
        bt = Rails.backtrace_cleaner.clean(bt)
      end

      message = "#{event.transaction_id} #{event.name} #{"%.2f" % event.duration}ms #{MultiJson.dump(event.payload[:args], pretty: Elasticity.config.pretty_json)}"

      if bt = event.payload[:backtrace]
        bt = Rails.backtrace_cleaner.clean(bt) if defined?(Rails)
        lines = bt[0,4].map { |l| color(l, GRAY) }.join("\n")
        message << "\n#{lines}"
      end

      debug(message)

      exception, message = event.payload[:exception]
      if exception
        error("{event.transaction_id} #{event.name} ERROR #{exception}: #{message}")
      end
    end
  end
end
