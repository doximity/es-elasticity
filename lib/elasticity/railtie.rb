module Elasticity
  class Railtie < Rails::Railtie
    initializer 'elasticity.initialize_logging' do
      ActiveSupport::Notifications.subscribe(/\.elasticity$/) do |name, start, finish, id, payload|
        time = (finish - start)*1000

        if logger = Elasticity.config.logger
          logger.debug "#{name} #{"%.2f" % time}ms #{MultiJson.dump(payload[:args], pretty: Elasticity.config.pretty_json)}"

          if payload[:backtrace].present?
            bt = Rails.backtrace_cleaner.clean(payload[:backtrace])
            logger.debug bt[:backtrace][0,4].join("\n")
          end

          exception, message = payload[:exception]
          if exception
            logger.error "#{name} #{exception}: #{message}"
          end
        end
      end
    end
  end
end
