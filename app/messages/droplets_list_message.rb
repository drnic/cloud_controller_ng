require 'messages/list_message'

module VCAP::CloudController
  class DropletsListMessage < ListMessage
    register_allowed_keys [
      :app_guid,
      :app_guids,
      :current,
      :guids,
      :order_by,
      :organization_guids,
      :package_guid,
      :page,
      :per_page,
      :space_guids,
      :states
    ]

    validates_with NoAdditionalParamsValidator

    validates :app_guids, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :current, inclusion: { in: ['true'], message: 'only accepts the value \'true\'' }, allow_nil: true, if: -> { app_guid.present? }
    validate :app_nested_request, if: -> { app_guid.present? }
    validate :not_app_nested_request, unless: -> { app_guid.present? }

    def to_param_hash
      super(exclude: [:app_guid, :package_guid])
    end

    def self.from_params(params)
      opts = params.dup
      %w(space_guids states app_guids guids organization_guids).each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end

    private

    def not_app_nested_request
      invalid_attributes = []
      invalid_attributes << :current if current
      errors.add(:base, "Unknown query parameter(s): '#{invalid_attributes.join("', '")}'") if invalid_attributes.present?
    end

    def app_nested_request
      invalid_attributes = []
      invalid_attributes << :app_guids if app_guids
      invalid_attributes << :organization_guids if organization_guids
      invalid_attributes << :space_guids if space_guids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_attributes.join("', '")}'") if invalid_attributes.present?
    end
  end
end
