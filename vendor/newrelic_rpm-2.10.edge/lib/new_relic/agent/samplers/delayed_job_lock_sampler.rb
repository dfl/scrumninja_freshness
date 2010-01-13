module NewRelic::Agent::Samplers
  class DelayedJobLockSampler < NewRelic::Agent::Sampler
    def initialize
      super :delayed_job_lock
    end
    
    def stats
      stats_engine.get_stats("DJ/Locked Jobs", false)
    end
    
    def local_env
      NewRelic::Control.instance.local_env
    end
    
    def worker_name
      local_env.dispatcher_instance_id
    end
    
    def locked_jobs
      Delayed::Job.count(:conditions => {:locked_by => worker_name})
    end
    
    def poll
      stats.record_data_point locked_jobs
    end
  end
end
