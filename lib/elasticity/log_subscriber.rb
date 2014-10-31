require "active_support/subscriber"
require "active_support/log_subscriber"

module Elasticity
  GRAY = "\e[90m"

  class LogSubscriber < ::ActiveSupport::LogSubscriber
    %w(exists create delete get_settings get_mapping flush get_alias get_aliases put_alias delete_alias exists_alias update_aliases).each do |method_name|
      define_method("index_#{method_name}") do |event|
        log_event(event)
      end
    end

    %w(index delete get search scroll delete_by_query bulk).each do |method_name|
      define_method(method_name) do |event|
        log_event(event)
      end
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
