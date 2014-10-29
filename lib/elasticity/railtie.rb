require "elasticity/log_subscriber"

module Elasticity
  class Railtie < Rails::Railtie
    initializer 'elasticity.initialize_logging' do
      LogSubscriber.attach_to(:elasticity)
    end
  end
end
