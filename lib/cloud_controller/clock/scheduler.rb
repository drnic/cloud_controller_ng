require 'clockwork'
require 'cloud_controller/clock/clock'

module VCAP::CloudController
  class Scheduler
    CLEANUPS = [
      { name: 'app_usage_events', class: Jobs::Runtime::AppUsageEventsCleanup, time: '18:00' },
      { name: 'app_events', class: Jobs::Runtime::AppEventsCleanup, time: '19:00' },
      { name: 'audit_events', class: Jobs::Runtime::EventsCleanup, time: '20:00' },
      { name: 'failed_jobs', class: Jobs::Runtime::FailedJobsCleanup, time: '21:00' },
      { name: 'service_usage_events', class: Jobs::Services::ServiceUsageEventsCleanup, time: '22:00' },
      { name: 'completed_tasks', class: Jobs::Runtime::PruneCompletedTasks, time: '23:00' },
      { name: 'expired_blob_cleanup', class: Jobs::Runtime::ExpiredBlobCleanup, time: '00:00' },
    ].freeze

    def initialize(config)
      @clock  = Clock.new
      @config = config
      @logger = Steno.logger('cc.clock')
    end

    def start
      start_daily_jobs
      start_frequent_jobs
      start_inline_jobs

      Clockwork.error_handler { |error| @logger.error(error) }
      Clockwork.run
    end

    private

    def start_inline_jobs
      clock_opts = {
        name:     'diego_sync',
        interval: @config.dig(:diego_sync, :frequency_in_seconds)
      }
      @clock.schedule_frequent_inline_job(clock_opts) do
        Jobs::Diego::Sync.new
      end
    end

    def start_frequent_jobs
      clock_opts = {
        name:     'pending_droplets',
        interval: @config.dig(:pending_droplets, :frequency_in_seconds)
      }
      @clock.schedule_frequent_worker_job(clock_opts) do
        Jobs::Runtime::PendingDropletCleanup.new(@config.dig(:pending_droplets, :expiration_in_seconds))
      end
    end

    def start_daily_jobs
      CLEANUPS.each do |cleanup_config|
        cutoff_age_in_days = @config.dig(cleanup_config[:name].to_sym, :cutoff_age_in_days)
        clock_opts = { name: cleanup_config[:name], at: cleanup_config[:time] }

        @clock.schedule_daily_job(clock_opts) do
          klass = cleanup_config[:class]
          cutoff_age_in_days ? klass.new(cutoff_age_in_days) : klass.new
        end
      end
    end
  end
end