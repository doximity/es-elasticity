module Elasticity
  module LiveRemap
    extend ActiveSupport::Concern

    included do
      class_attribute :redis
    end

    module ClassMethods
      def remap!
        started = redis.set(remap_redis_key, Time.now.utc.iso8601, nx: true)
        raise "Live remap is already running for #{self}" unless started
      end

      def abort_remap!
        redis.del(remap_redis_key)
      end

      def remapping?
        redis.exists(remap_redis_key)
      end

      private

      def remap_redis_key
        "elasticity:live_remap:#{namespaced_index_name}"
      end
    end
  end
end