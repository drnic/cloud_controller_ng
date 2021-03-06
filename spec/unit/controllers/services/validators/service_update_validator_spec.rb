require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::ServiceUpdateValidator, :services do
    describe '#validate_service_instance' do
      let(:service_broker_url) { "http://example.com/v2/service_instances/#{service_instance.guid}" }
      let(:service_broker) { ServiceBroker.make(broker_url: 'http://example.com', auth_username: 'auth_username', auth_password: 'auth_password') }
      let(:service) { Service.make(plan_updateable: true, service_broker: service_broker) }
      let(:old_service_plan) { ServicePlan.make(:v2, service: service, free: true) }
      let(:new_service_plan) { ServicePlan.make(:v2, service: service) }
      let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }
      let(:space) { service_instance.space }

      let(:update_attrs) { {} }
      let(:args) do
        {
          space: space,
          service_plan: old_service_plan,
          service: service,
          update_attrs: update_attrs
        }
      end

      context 'when the update to the service instance is valid' do
        it 'returns true' do
          expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
        end
      end

      context 'when the update to the service instance is invalid' do
        context 'when the update changes the space' do
          let(:update_attrs) { { 'space_guid' => 'asdf' } }

          it 'raises a validation error' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /Cannot update space/)
          end
        end

        context 'when the requested plan is not bindable' do
          let(:new_service_plan) { ServicePlan.make(:v2, service: service, bindable: false) }
          let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

          context 'and service bindings exist' do
            before do
              ServiceBinding.make(
                app: AppModel.make(space: service_instance.space),
                service_instance: service_instance
              )
            end

            it 'raises a validation error' do
              expect {
                ServiceUpdateValidator.validate!(service_instance, args)
              }.to raise_error(CloudController::Errors::ApiError, /cannot switch to non-bindable/)
            end
          end

          context 'and service bindings do not exist' do
            it 'returns true' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
            end
          end
        end

        context 'when the service does not allow plan updates' do
          before do
            service.plan_updateable = false
          end

          let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

          it 'raises a validation error if the plan changes' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /service does not support changing plans/)
          end

          context 'when the plan does not change' do
            let(:update_attrs) { { 'service_plan_guid' => old_service_plan.guid } }

            it 'returns true' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
            end
          end
        end

        context 'when the plan does not exist' do
          let(:update_attrs) { { 'service_plan_guid' => 'does-not-exist' } }

          it 'raises a validation error' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /Plan/)
          end
        end

        context 'when the plan is in a different service' do
          let(:other_broker) { ServiceBroker.make }
          let(:other_service) { Service.make(plan_updateable: true, service_broker: other_broker) }
          let(:new_service_plan) { ServicePlan.make(:v2, service: other_service) }
          let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

          it 'raises a validation error' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /Plan/)
          end
        end

        context 'when the service instance is shared' do
          let(:shared_space) { Space.make }

          before do
            service_instance.add_shared_space(shared_space)
          end

          context 'when the name is changed' do
            let(:update_attrs) { { 'name' => 'something_new' } }

            it 'raises a validation error' do
              expect {
                ServiceUpdateValidator.validate!(service_instance, args)
              }.to raise_error(CloudController::Errors::ApiError, /shared cannot be renamed/)
            end
          end

          context 'when the name is not changed' do
            let(:update_attrs) { { 'name' => service_instance.name } }

            it 'succeeds' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
            end
          end
        end

        context 'paid plans' do
          let(:old_service_plan) { ServicePlan.make(:v2, service: service, free: false) }

          let(:free_quota) do
            QuotaDefinition.make(
              total_services: 10,
              non_basic_services_allowed: false
            )
          end

          let(:free_plan) { ServicePlan.make(:v2, free: true) }
          let(:org) { Organization.make(quota_definition: free_quota) }
          let(:developer) { make_developer_for_space(space) }

          context 'when paid plans are disabled for the quota' do
            let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }

            before do
              space.space_quota_definition = free_quota
              space.space_quota_definition.save
            end

            context 'when changing the instance parameters' do
              let(:update_attrs) { { 'toppings' => 'anchovies' } }

              it 'errors' do
                expect {
                  ServiceUpdateValidator.validate!(service_instance, args)
                }.to raise_error(CloudController::Errors::ApiError, /paid service plans are not allowed/)
              end
            end

            context 'when changing to an unpaid plan from a paid plan' do
              let(:new_service_plan) { ServicePlan.make(:v2, service: service, free: true) }
              let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

              it 'succeeds' do
                expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
              end

              it 'does not update the plan on the service instance' do
                ServiceUpdateValidator.validate!(service_instance, args)
                expect(service_instance.service_plan).to eq(old_service_plan)
                expect(service_instance.reload.service_plan).to eq(old_service_plan)
              end
            end

            context 'when changing to a different paid plan from a paid plan' do
              let(:new_service_plan) { ServicePlan.make(:v2, service: service, free: false) }
              let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

              it 'errors' do
                expect {
                  ServiceUpdateValidator.validate!(service_instance, args)
                }.to raise_error(CloudController::Errors::ApiError, /paid service plans are not allowed/)
              end

              it 'does not update the plan on the service instance' do
                expect {
                  ServiceUpdateValidator.validate!(service_instance, args)
                }.to raise_error(CloudController::Errors::ApiError)

                expect(service_instance.service_plan).to eq(old_service_plan)
                expect(service_instance.reload.service_plan).to eq(old_service_plan)
              end
            end
          end

          context 'when paid plans are enabled for the quota' do
            let(:new_service_plan) { ServicePlan.make(:v2, service: service, free: false) }
            let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

            it 'succeeds for paid plans' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
            end
          end
        end
      end
    end
  end
end
