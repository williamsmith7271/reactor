require "reactor/version"
require "reactor/errors"
require "reactor/static_subscribers"
require "reactor/workers"
require "reactor/subscription"
require "reactor/models"
require "reactor/controllers"
require "reactor/event"

# FIXME: should only be included in test environments
require "reactor/testing"

module Reactor
  SUBSCRIBERS = {}.with_indifferent_access

  module_function

  def subscribers
    SUBSCRIBERS
  end

  def add_subscriber(event_name, worker_class)
    subscribers[event_name] ||= []
    subscribers[event_name] << worker_class
  end

  def subscriber_namespace
    Reactor::StaticSubscribers
  end
end

ActiveRecord::Base.send(:include, Reactor::Publishable)
ActiveRecord::Base.send(:include, Reactor::Subscribable)
