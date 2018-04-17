require 'messages/list_message'

module VCAP::CloudController
  class AppBuildsListMessage < ListMessage
    ALLOWED_KEYS = [
      :order_by,
      :page,
      :per_page,
      :states
    ].freeze

    attr_accessor(*ALLOWED_KEYS)
    validates_with NoAdditionalParamsValidator

    validates :states, array: true, allow_nil: true

    def self.from_params(params)
      opts = params.dup
      %w(states).each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end
  end
end
