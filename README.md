# reactor.gem

### A Sidekiq-backed pub/sub layer for your Rails app.

[![Build Status](https://travis-ci.org/hired/reactor.svg?branch=master)](https://travis-ci.org/hired/reactor)

This gem aims to provide the following tools to augment your ActiveRecord & Sidekiq stack.

 1. Barebones event API through Sidekiq to publish whatever you want
 2. Database-driven API to manage subscribers so that users may rewire whatever you let them (transactional emails, campaigns, etc...)
 3. Static/Code-driven API to subscribe a basic ruby block to an event.
 4. A new communication pattern between your ActiveRecord models that runs asynchronously through Sidekiq.
    a. describe model lifecycle events and callbacks with class-level helper methods/DSL

## Installation

Add this line to your application's Gemfile:

    gem 'reactor'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install reactor

## Usage

Well, this is evolving, so it's probably best to go read the specs.


### Barebones API

```ruby
Reactor::Event.publish(:event_name, any: 'data', you: 'want')
```

### ActiveModel extensions

#### Publishable

  Describe lifecycle events like so

```ruby
publishes :my_model_created
publishes :state_has_changed, if: -> { state_has_changed? }
```

#### Subscribable

  You can now bind any block to an event in your models like so

```ruby
on_event :any_event do |event|
  event.target.do_something_about_it!
end
```

  Static subscribers like these are automatically placed into Sidekiq and executed in the background

  It's also possible to run a subscriber block in memory like so

```ruby
on_event :any_event, in_memory: true do |event|
  event.target.do_something_about_it_and_make_the_user_wait!
end
```

#### ResourceActionable

    Enforce a strict 1:1 match between your event model and database model with this controller mixin.


```ruby
class PetsController < ApplicationController
  include Reactor::ResourceActionable
  actionable_resource :@pet

  # GET /pets
  # GET /pets.json
  def index
    @pets = current_user.pets

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @pets }
    end
  end

  def show
    @pet = current_user.pets.find(params[:id])
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @pet }
    end
  end
end

```

Now your index action (and any of the other RESTful actions in that controller) will fire a useful event for you to bind to and log.

*Important* Reactor::ResourceActionable has one major usage constraints:

Your controller *must* have a method called "action_event" with this signature.
```ruby
def action_event(name, options = {})
  # Here's what ours looks like, but yours may look different.
  actor = options[:actor] || current_user
  actor.publish(name, options.merge(default_action_parameters))
  #where default_action_parameters includes things like ip_address, referrer, user_agent
end
```

Once you write your own action_event to describe your event data model's base attributes, your ResourceActionable endpoints will now fire events that map like so (for the example above):

<dl>
<dt>index =></dt>
<dd>"pets_indexed"</dd>
</dl>
 
<dl>
<dt>show =></dt>
<dd>"pet_viewed", target: @pet</dd>
</dl>

<dl>
<dt>new =></dt>
<dd>"new_pet_form_viewed"</dd>
</dl>

<dl>
<dt>edit =></dt>
<dd> "edit_pet_form_viewed", target: @pet</dd>
</dl>

<dl>
<dt>create =></dt>
<dd> when valid => "pet_created", target: @pet, attributes: params[:pet]
<br />
  when invalid => "pet_create_failed", errors: @pet.errors, attributes: params[:pet]</dd>
</dl>

<dl>
<dt>update =></dt>
<dd> 
when valid => "pet_updated", target: @pet, changes: @pet.previous_changes.as_json
<br />
  when invalid => "pet_update_failed", target: @pet,
                  errors: @pet.errors.as_json, attributes: params[:pet]
</dd>
</dl>

<dl>
<dt>destroy =></dt>
<dd>"pet_destroyed", last_snapshot: @pet.as_jsont</dd>
</dl>


##### What for?

If you're obsessive about data like us, you'll have written a '*' subscriber that logs every event fired in the system. With information-dense resource information logged for each action a user performs, it will be trivial for a data analyst to determine patterns in user activity. For example, with the above data being logged for the pet resource, we can easily
* determine which form field validations are constantly being hit by users
* see if there are any fields that are consistently ignored on that form until later
* recover data from the last_snapshot of a destroyed record
* write a small conversion funnel analysis to see who never makes it back to a record to update it
* bind arbitrary logic anywhere in the codebase (see next example) to that specific request without worrying about the logic being run during the request (all listeners are run in the background by Sidekiq)

For example, in an action mailer.

```ruby
class MyMailer < ActionMailer::Base
  include Reactor::EventMailer

  on_event :pet_created do |event|
    @user = event.actor
    @pet = event.target
    mail to: @user.email, subject: "Your pet is already hungry!", body: "feed it."
  end
end
```

Or in a model, concern, or other business logic file.

```ruby
class MyClass
  include Reactor::Subscribable

  on_event :pet_updated do |event|
     event.actor.recalculate_expensive_something_for(event.target)
  end
end
```

### Testing

Calling `Reactor.test_mode!` enables test mode.  (You should call this as early as possible, before your subscriber classes
are declared).  In test mode, no subscribers will fire unless they are specifically enabled, which can be accomplished
by calling
```ruby
Reactor.enable_test_mode_subscriber(MyAwesomeSubscriberClass)
```

We also provide
```ruby
Reactor.with_subscriber_enabled(MyClass) do
  # stuff
end
```

for your testing convenience.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Open Source by Hired

[Hired](https://hired.com/?utm_source=opensource&utm_medium=reactor&utm_campaign=readme) wants to make sure every developer in the world has a kick-ass job with an awesome salary and great coworkers. 

Our site allows you to quickly create a profile and then get offers from some of the top companies in the world - with salary and equity disclosed up-front. Average Ruby engineer salaries on Hired are around $120,000 per year, but if you are smart enough to use Reactor you'll probably be able to get more like $150,000 :).


<a href="https://hired.com/?utm_source=opensource&utm_medium=reactor&utm_campaign=readme-banner" target="_blank">
<img src="https://dmrxx81gnj0ct.cloudfront.net/public/hired-banner-light-1-728x90.png" alt="Hired" width="728" height="90" align="center"/>
</a>

We are Ruby developers ourselves, and we use all of our open source projects in production. We always encourge forks, pull requests, and issues. Get in touch with the Hired Engineering team at _opensource@hired.com_.

