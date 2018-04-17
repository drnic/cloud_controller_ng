require 'messages/base_message'
require 'messages/validators/bits_data_validator'
require 'messages/validators/docker_data_validator'

module VCAP::CloudController
  class PackageCreateMessage < BaseMessage
    ALLOWED_KEYS = [:relationships, :type, :data].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator,
      DockerDataValidator,
      BitsDataValidator,
      RelationshipValidator

    validates :type, inclusion: { in: %w(bits docker), message: 'must be one of \'bits, docker\'' }

    delegate :app_guid, to: :relationships_message

    def self.create_from_http_request(body)
      PackageCreateMessage.new(body.deep_symbolize_keys)
    end

    def bits_type?
      type == 'bits'
    end

    def docker_type?
      type == 'docker'
    end

    def docker_data
      OpenStruct.new(data) if docker_type?
    end

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    def audit_hash
      result = super

      if result['data']
        result['data'][:password] = VCAP::CloudController::Presenters::V3::PackagePresenter::REDACTED_MESSAGE
      end

      result
    end

    class Relationships < BaseMessage
      ALLOWED_KEYS = [:app].freeze
      attr_accessor(*ALLOWED_KEYS)

      validates_with NoAdditionalKeysValidator

      validates :app, presence: true, allow_nil: false, to_one_relationship: true

      def app_guid
        HashUtils.dig(app, :data, :guid)
      end
    end
  end
end
