require 'spec_helper'
require 'cloud_controller/locket/client'

RSpec.describe VCAP::CloudController::Locket::Client do
  describe 'acceptance' do
    before do

    end
    
    it 'works' do
      config = {
        url: "http://locket.example.com:1234",
        http_client: HttpClient.new()
      }
      eager_client = VCAP::CloudController::Locket::Client.new(config)
      too_late_client = VCAP::CloudController::Locket::Client.new(config)

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
