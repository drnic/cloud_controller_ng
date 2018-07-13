require 'spec_helper'
require 'cloud_controller/locket/client'

RSpec.describe VCAP::CloudController::Locket::Client do
  describe 'acceptance' do
    it 'works' do
      eager_client = VCAP::CloudController::Locket::Client.new
      too_late_client = VCAP::CloudController::Locket::Client.new

      shared_state = "empty"

      eager_client.with_lock('the-lock') do
        shared_state = 'eager'

        too_late_client.with_lock('the-lock') do
          shared_state = 'too late' # block should be skipped
        end
      end
      expect(shared_state).to eq('eager')

      too_late_client.with_lock('the-lock') do
        shared_state = 'too_late'
      end
      expect(shared_state).to be('too_late')
    end
  end
end
