module Elasticity
  class Railtie < Rails::Railtie
    initializer 'elasticity.initialize_logging' do
      ActiveSupport::Notifications.subscribe(/\.elasticity$/) do |name, start, finish, id, payload|
        puts name
        time = (finish - start)*1000

        if logger = Elasticity.config.logger
          logger.debug "#{name} #{"%.2f" % time}ms #{MultiJson.dump(payload[:args], pretty: Elasticity.config.pretty_json)}"

          exception, message = payload[:exception]
          if exception
            logger.error "#{name} #{exception}: #{message}"
          end
        end
      end
    end
  end
end
