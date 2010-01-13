
module NewRelic::Agent::Instrumentation
  # == NewRelic instrumentation for controllers
  #
  # This instrumentation is applied to the action controller by default if the agent
  # is actively collecting statistics.  It will collect statistics for the 
  # given action.
  #
  # In cases where you don't want to instrument the top level action, but instead
  # have other methods which are dispatched to by your action, and you want to treat
  # these as distinct actions, then what you need to do is use
  # #perform_action_with_newrelic_trace
  #
  module ControllerInstrumentation
    
    def self.included(clazz) # :nodoc:
      clazz.extend(ClassMethods)
    end
    
    # This module is for importing stubs when the agent is disabled
    module ClassMethodsShim # :nodoc:
      def newrelic_ignore(*args); end
      def newrelic_ignore_apdex(*args); end
    end
    
    module Shim # :nodoc:
      def self.included(clazz)
        clazz.extend(ClassMethodsShim)
      end
      def newrelic_notice_error(*args); end
      def new_relic_trace_controller_action(*args); yield; end
      def newrelic_metric_path; end
      def perform_action_with_newrelic_trace(*args); yield; end
    end
    
    module ClassMethods
      # Have NewRelic ignore actions in this controller.  Specify the actions as hash options
      # using :except and :only.  If no actions are specified, all actions are ignored.
      def newrelic_ignore(specifiers={})
        newrelic_ignore_aspect('do_not_trace', specifiers)
      end
      # Have NewRelic omit apdex measurements on the given actions.  Typically used for 
      # actions that are not user facing or that skew your overall apdex measurement.
      # Accepts :except and :only options, as with #newrelic_ignore.
      def newrelic_ignore_apdex(specifiers={})
        newrelic_ignore_aspect('ignore_apdex', specifiers)
      end
      
      def newrelic_ignore_aspect(property, specifiers={}) # :nodoc:
        if specifiers.empty?
          self.newrelic_write_attr property, true
        elsif ! (Hash === specifiers)
          logger.error "newrelic_#{property} takes an optional hash with :only and :except lists of actions (illegal argument type '#{specifiers.class}')"
        else
          self.newrelic_write_attr property, specifiers
        end
      end
      
      # Should be monkey patched into the controller class implemented
      # with the inheritable attribute mechanism.
      def newrelic_write_attr(attr_name, value) # :nodoc:
        instance_variable_set "@#{attr_name}", value
      end
      def newrelic_read_attr(attr_name) # :nodoc:
        instance_variable_get "@#{attr_name}"
      end
      
      # Add transaction tracing to the given method.  This will treat
      # the given method as a main entrypoint for instrumentation, just
      # like controller actions are treated by default.  Useful especially
      # for background tasks. 
      #
      # Example for background job:
      #   class Job
      #     include NewRelic::Agent::Instrumentation::ControllerInstrumentation
      #     def run(task)
      #        ...
      #     end
      #     # Instrument run so tasks show up under task.name.  Note single
      #     # quoting to defer eval to runtime.
      #     add_transaction_tracer :run, :name => '#{args[0].name}'
      #   end
      #
      # Here's an example of a controller that uses a dispatcher
      # action to invoke operations which you want treated as top
      # level actions, so they aren't all lumped into the invoker
      # action.
      #      
      #   MyController < ActionController::Base
      #     include NewRelic::Agent::Instrumentation::ControllerInstrumentation
      #     # dispatch the given op to the method given by the service parameter.
      #     def invoke_operation
      #       op = params['operation']
      #       send op
      #     end
      #     # Ignore the invoker to avoid double counting
      #     newrelic_ignore :only => 'invoke_operation'
      #     # Instrument the operations:
      #     add_transaction_tracer :print
      #     add_transaction_tracer :show
      #     add_transaction_tracer :forward
      #   end
      #
      # Here's an example of how to pass contextual information into the transaction
      # so it will appear in transaction traces:
      #
      #   class Job
      #     include NewRelic::Agent::Instrumentation::ControllerInstrumentation
      #     def process(account)
      #        ...
      #     end
      #     # Include the account name in the transaction details.  Note the single
      #     # quotes to defer eval until call time.
      #     add_transaction_tracer :process, :params => '{ :account_name => args[0].name }'
      #   end
      #
      # See NewRelic::Agent::Instrumentation::ControllerInstrumentation#perform_action_with_newrelic_trace
      # for the full list of available options.
      #
      def add_transaction_tracer(method, options={})
        # The metric path:
        options[:name] ||= method.to_s
        # create the argument list:
        options_arg = []
        options.each do |key, value|
          valuestr = case
          when value.is_a?(Symbol)
            value.inspect
          when key == :params
            value.to_s
          else
              %Q["#{value.to_s}"]
          end
          options_arg << %Q[:#{key} => #{valuestr}]
        end
        class_eval <<-EOC
        def #{method.to_s}_with_newrelic_transaction_trace(*args, &block)
          perform_action_with_newrelic_trace(#{options_arg.join(',')}) do
            #{method.to_s}_without_newrelic_transaction_trace(*args, &block)
          end
        end
        EOC
        alias_method "#{method.to_s}_without_newrelic_transaction_trace", method.to_s
        alias_method method.to_s, "#{method.to_s}_with_newrelic_transaction_trace"
      end
    end
    
    # Must be implemented in the controller class:
    # Determine the path that is used in the metric name for
    # the called controller action.  Of the form controller_path/action_name
    # 
    def newrelic_metric_path(action_name_override = nil) # :nodoc:
      raise "Not implemented!"
    end
    
    # Yield to the given block with NewRelic tracing.  Used by 
    # default instrumentation on controller actions in Rails and Merb.
    # But it can also be used in custom instrumentation of controller
    # methods and background tasks.
    #
    # This is the method invoked by instrumentation added by the
    # <tt>ClassMethods#add_transaction_tracer</tt>.  
    #
    # Here's a more verbose version of the example shown in
    # <tt>ClassMethods#add_transaction_tracer</tt> using this method instead of
    # #add_transaction_tracer.
    #
    # Below is a controller with an +invoke_operation+ action which
    # dispatches to more specific operation methods based on a
    # parameter (very dangerous, btw!).  With this instrumentation,
    # the +invoke_operation+ action is ignored but the operation
    # methods show up in RPM as if they were first class controller
    # actions
    #    
    #   MyController < ActionController::Base
    #     include NewRelic::Agent::Instrumentation::ControllerInstrumentation
    #     # dispatch the given op to the method given by the service parameter.
    #     def invoke_operation
    #       op = params['operation']
    #       perform_action_with_newrelic_trace(:name => op) do
    #         send op, params['message']
    #       end
    #     end
    #     # Ignore the invoker to avoid double counting
    #     newrelic_ignore :only => 'invoke_operation'
    #   end
    #
    # By passing a block in combination with specific arguments, you can 
    # invoke this directly to capture high level information in
    # several contexts:
    #
    # * Pass <tt>:category => :controller</tt> and <tt>:name => actionname</tt>
    #   to treat the block as if it were a controller action, invoked
    #   inside a real action.  <tt>:name</tt> is the name of the method, and is
    #   used in the metric name.
    #
    # When invoked directly, pass in a block to measure with some
    # combination of options:
    #
    # * <tt>:category => :controller</tt> indicates that this is a
    #   controller action and will appear with all the other actions.  This
    #   is the default.
    # * <tt>:category => :task</tt> indicates that this is a
    #   background task and will show up in RPM with other background
    #   tasks instead of in the controllers list
    # * <tt>:category => :rack</tt> if you are instrumenting a rack
    #   middleware call.  The <tt>:name</tt> is optional, useful if you 
    #   have more than one potential transaction in the #call.
    # * <tt>:category => :uri</tt> indicates that this is a
    #   web transaction whose name is a normalized URI, where  'normalized'
    #   means the URI does not have any elements with data in them such
    #   as in many REST URIs.
    # * <tt>:params => {...}</tt> to provide information about the context
    #   of the call, used in transaction trace display, for example:
    #   <tt>:params => { :account => @account.name, :file => file.name }</tt>
    # * <tt>:name => action_name</tt> is used to specify the action
    #   name used as part of the metric name
    # * <tt>:force => true</tt> indicates you should capture all
    #   metrics even if the #newrelic_ignore directive was specified
    # * <tt>:class_name => aClass.name</tt> is used to override the name
    #   of the class when used inside the metric name.  Default is the
    #   current class.
    # * <tt>:path => metric_path</tt> is *deprecated* in the public API.  It
    #   allows you to set the entire metric after the category part.  Overrides
    #   all the other options.
    #
    # If a single argument is passed in, it is treated as a metric
    # path.  This form is deprecated.
    def perform_action_with_newrelic_trace(*args, &block)
      
      NewRelic::Agent.instance.ensure_worker_thread_started
      
      # Skip instrumentation based on the value of 'do_not_trace' and if 
      # we aren't calling directly with a block.
      if !block_given? && _is_filtered?('do_not_trace')
        # Also ignore all instrumentation in the call sequence
        NewRelic::Agent.disable_all_tracing do
          return perform_action_without_newrelic_trace(*args)
        end
      end
      frame_data = _push_metric_frame(block_given? ? args : [])
      
      return perform_action_with_newrelic_profile(frame_data.metric_name, frame_data.path, args, &block) if NewRelic::Control.instance.profiling?
      
      NewRelic::Agent.trace_execution_scoped frame_data.recorded_metrics, :force => frame_data.force_flag do
        frame_data.start_transaction
        begin
          NewRelic::Agent::BusyCalculator.dispatcher_start frame_data.start
          if block_given?
            yield
          else
            perform_action_without_newrelic_trace(*args)
          end
        rescue Exception => e
          if frame_data.exception != e
            NewRelic::Agent.instance.error_collector.notice_error(e, nil, frame_data.metric_name, frame_data.filtered_params)
            frame_data.exception = e
          end
          raise e
        ensure
          NewRelic::Agent::BusyCalculator.dispatcher_finish
          # Look for a metric frame in the thread local and process it.
          # Clear the thread local when finished to ensure it only gets called once.
          frame_data.record_apdex unless _is_filtered?('ignore_apdex')
          frame_data.pop
        end
      end
    end
    
    # Experimental
    def perform_action_with_newrelic_profile(metric_name, path, args)
      NewRelic::Agent.trace_execution_scoped metric_name do
        MetricFrame.current.start_transaction
        NewRelic::Agent.disable_all_tracing do
          # turn on profiling
          profile = RubyProf.profile do
            if block_given?
              yield
            else
              perform_action_without_newrelic_trace(*args)
            end
          end
          NewRelic::Agent.instance.transaction_sampler.notice_profile profile
        end
      end
    end
    
    # Write a metric frame onto a thread local if there isn't already one there.
    # If there is one, just update it.
    def _push_metric_frame(args) # :nodoc:
      frame_data = MetricFrame.current
      
      frame_data.apdex_start ||= _detect_upstream_wait(frame_data.start)
      
      # If a block was passed in, then the arguments represent options for the instrumentation,
      # not app method arguments.
      if args.any?
        frame_data.force_flag = args.last.is_a?(Hash) && args.last[:force]
        category, path, available_params = _convert_args_to_path(args)
      else
        category = 'Controller'
        path = newrelic_metric_path
        available_params = self.respond_to?(:params) ? self.params : {} 
      end
      frame_data.push(category, path)
      frame_data.filtered_params = (respond_to? :filter_parameters) ? filter_parameters(available_params) : available_params
      frame_data.available_request ||= (respond_to? :request) ? request : nil
      frame_data
    end
    
    protected
    
    def _convert_args_to_path(args)
      options =  args.last.is_a?(Hash) ? args.pop : {}
      category = 'Controller'
      params = options[:params] || {}
      unless path = options[:path]
        category = case options[:category]
        when :controller, nil then 'Controller'
        when :task then 'Controller' #'OtherTransaction/Background' # 'Task'
        when :rack then 'Controller/Rack' #'WebTransaction/Rack'
        when :uri then 'Controller' #'WebTransaction/Uri'
        when :sinatra then 'Controller/Sinatra' #'WebTransaction/Uri'
        # for internal use only
        else options[:category].to_s
        end
        # To be consistent with the ActionController::Base#controller_path used in rails to determine the
        # metric path, we drop the controller off the end of the path if there is one.
        action = options[:name] || args.first 
        metric_class = options[:class_name] || (self.is_a?(Class) ? self.name : self.class.name)
        
        path = metric_class
        path += ('/' + action) if action
      end
      [category, path, params]
    end

    # Filter out 
    def _is_filtered?(key)
      ignore_actions = self.class.newrelic_read_attr(key) if self.class.respond_to? :newrelic_read_attr
      case ignore_actions
      when nil; false
      when Hash
        only_actions = Array(ignore_actions[:only])
        except_actions = Array(ignore_actions[:except])
        only_actions.include?(action_name.to_sym) || (except_actions.any? && !except_actions.include?(action_name.to_sym))
      else
        true
      end
    end
    
    def _detect_upstream_wait(now)
      if newrelic_request_headers
        entry_time = newrelic_request_headers['HTTP_X_REQUEST_START'] and
        entry_time = entry_time[/t=(\d+)/, 1 ] and 
        http_entry_time = entry_time.to_f/1e6
      end
      # If we didn't find the custom header, look for the mongrel timestamp
      http_entry_time ||= Thread.current[:started_on] and http_entry_time = http_entry_time.to_f
      if http_entry_time
        queue_stat = NewRelic::Agent.agent.stats_engine.get_stats_no_scope 'WebFrontend/Mongrel/Average Queue Time'  
        queue_stat.trace_call(now - http_entry_time)
      end
      http_entry_time || now
    end
    
    def _dispatch_stat
      NewRelic::Agent.agent.stats_engine.get_stats_no_scope 'HttpDispatcher'  
    end
    
    # Should be implemented in the dispatcher class
    def newrelic_response_code; end
    
    def newrelic_request_headers
      self.respond_to?(:request) && self.request.respond_to?(:headers) && self.request.headers
    end
    
  end 
end  
