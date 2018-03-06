#
# Run this before specs if you want to speed up tests by trading out code coverage into subscribers
#
def stub_reactor_subscribers
  Reactor::SUBSCRIBERS.each do |_event, subscribers|
    subscribers.each do |subscriber|
      allow(subscriber).to receive(:perform_where_needed)
    end
  end
end

#
# If stubbing out reactor in test, use this method to re-enable a specific subscriber
# to test its logic.
#
def allow_reactor_subscriber(subscribable_class)
  worker_module_name = "Reactor::StaticSubscribers::#{subscribable_class}"
  worker_module_name.safe_constantize.constants.each do |worker_class_name|
    worker_class = "#{worker_module_name}::#{worker_class_name}".safe_constantize
    allow(worker_class).to receive(:perform_where_needed).and_call_original
  end

  yield if block_given? # yes you can use block syntax if you want
end

#
# If you publish events in ActiveRecord lifecycle hooks, you're gonna have a bad time.
#
# But inevitably it may make sense for you (yay software), in which case you may want to
#  disable a subscriber if you're testing logic around it.
#
def disable_reactor_subscriber(subscribable_class)
  worker_module_name = "Reactor::StaticSubscribers::#{subscribable_class}"
  worker_module_name.safe_constantize.constants.each do |worker_class_name|
    worker_class = "#{worker_module_name}::#{worker_class_name}".safe_constantize
    allow(worker_class).to receive(:perform_where_needed).and_return(nil)
  end

  if block_given? # yes you can use block syntax if you want
    begin
      yield
    ensure
      allow_reactor_subscriber(subscribable_class) # and if you do, expect it to be re-enabled after
    end
  end
end