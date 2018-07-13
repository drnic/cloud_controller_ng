module VCAP::CloudController
  module Locket

    class Client
      def with_lock(lock_name)
        yield
      end
    end
  end
end
