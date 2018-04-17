require 'messages/base_message'

module VCAP::CloudController
  class AppUpdateEnvironmentVariablesMessage < BaseMessage
    ALLOWED_KEYS = [:var].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.create_from_http_request(body)
      AppUpdateEnvironmentVariablesMessage.new(body.deep_symbolize_keys)
    end

    validates_with NoAdditionalKeysValidator
    validates_with StringValuesOnlyValidator

    validates :var, environment_variables: true

    def audit_hash
      result = super
      result['environment_variables'] = result.delete('var')
      result
    end
  end
end
