module VCAP::CloudController
  module Locket

    class Client

      def initialize(options)

      end


      def with_lock(lock_name)
        yield
      end

      private

      def encode

      end

      def decode

      end

    end
  end
end
