# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class PoolConfig # :nodoc:
      include Mutex_m

      attr_reader :db_config, :role, :shard
      attr_accessor :schema_cache, :connection_class

      INSTANCES = ObjectSpace::WeakMap.new
      private_constant :INSTANCES

      class << self
        def discard_pools!
          INSTANCES.each_key(&:discard_pool!)
        end

        def disconnect_all!
          INSTANCES.each_key(&:disconnect!)
        end
      end

      def initialize(connection_class, db_config, role, shard)
        super()
        @connection_class = connection_class
        @db_config = db_config
        @role = role
        @shard = shard
        @pool = nil
        INSTANCES[self] = self
      end

      def connection_name
        if connection_class.primary_class?
          "ActiveRecord::Base"
        else
          connection_class.name
        end
      end

      def disconnect!
        ActiveSupport::ForkTracker.check!

        return unless @pool

        synchronize do
          return unless @pool

          @pool.automatic_reconnect = false
          @pool.disconnect!
        end

        nil
      end

      def pool
        ActiveSupport::ForkTracker.check!

        @pool || synchronize { @pool ||= ConnectionAdapters::ConnectionPool.new(self) }
      end

      def discard_pool!
        return unless @pool

        synchronize do
          return unless @pool

          @pool.discard!
          @pool = nil
        end
      end
    end
  end
end

ActiveSupport::ForkTracker.after_fork { ActiveRecord::ConnectionAdapters::PoolConfig.discard_pools! }
