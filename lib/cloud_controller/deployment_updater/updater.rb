require 'actions/process_restart'

module VCAP::CloudController
  module DeploymentUpdater
    class Updater
      def self.update
        logger = Steno.logger('cc.deployment_updater.update')
        logger.info('run-deployment-update')

        deployments = DeploymentModel.where(state: DeploymentModel::DEPLOYING_STATE)

        deployments.each do |deployment|
          begin
            scale_deployment(deployment, logger)
          rescue => e
            error_name = e.is_a?(CloudController::Errors::ApiError) ? e.name : e.class.name
            logger.error(
              'error-scaling-deployment',
              deployment_guid: deployment.guid,
              error: error_name,
              error_message: e.message,
              backtrace: e.backtrace.join("\n")
            )
          end
        end
      end

      private_class_method

      def self.scale_deployment(deployment, logger)
        app = deployment.app
        web_process = app.web_process
        deploying_web_process = deployment.deploying_web_process

        return unless ready_to_scale?(deployment, logger)

        if web_process.instances == 0
          ProcessModel.db.transaction do
            deployment.lock!

            deploying_web_process.update(type: ProcessTypes::WEB)
            web_process.delete

            app.reload
            restart_non_web_processes(app)
            deployment.update(state: DeploymentModel::DEPLOYED_STATE)
          end
        elsif web_process.instances == 1
          web_process.update(instances: web_process.instances - 1)
        else
          ProcessModel.db.transaction do
            web_process.update(instances: web_process.instances - 1)
            deploying_web_process.update(instances: deploying_web_process.instances + 1)
          end
        end

        logger.info("ran-deployment-update-for-#{deployment.guid}")
      end

      def self.ready_to_scale?(deployment, logger)
        instances = instance_reporters.all_instances_for_app(deployment.deploying_web_process)
        instances.all? { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING }
      rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
        logger.info("skipping-deployment-update-for-#{deployment.guid}")
        return false
      end

      def self.instance_reporters
        CloudController::DependencyLocator.instance.instances_reporters
      end

      def self.restart_non_web_processes(app)
        app.processes.each do |process|
          next if process.web?

          VCAP::CloudController::ProcessRestart.restart(process: process, config: Config.config, stop_in_runtime: true)
        end
      end
    end
  end
end
