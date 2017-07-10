require 'spec_helper'
require 'sidekiq/testing'

class Publisher < ActiveRecord::Base
  belongs_to :pet

  def ring_timeout
    start_at + 30.seconds
  end

  def ring_timeout_was
    previous_changes[:start_at][0] + 30.seconds
  end

  publishes :bell
  publishes :ring, at: :ring_timeout, watch: :start_at
  publishes :begin, at: :start_at, additional_info: 'curtis was here'
  publishes :conditional_event_on_save, at: :start_at, if: -> { we_want_it }
  publishes :woof, actor: :pet, target: :self
end

class TestSubscriber < Reactor::Subscriber
  @@called = false

  on_fire do
    @@called = true
  end
end

describe Reactor::Publishable do
  before do
    TestSubscriber.destroy_all
    TestSubscriber.class_variable_set(:@@called, false)
  end

  describe 'publish' do
    let(:pet) { Pet.create! }
    let(:publisher) { Publisher.create!(pet: pet, start_at: Time.current + 1.day, we_want_it: false) }

    it 'publishes an event with actor_id and actor_type set as self' do
      publisher
      expect(Reactor::Event).to receive(:publish).with(:an_event, what: 'the', actor: publisher)
      publisher.publish(:an_event, {what: 'the'})
    end

    it 'publishes an event with provided actor and target methods' do
      allow(Reactor::Event).to receive(:publish).exactly(5).times
      publisher
      expect(Reactor::Event).to have_received(:publish).with(:woof, a_hash_including(actor: pet, target: publisher))
    end

    it 'reschedules an event when the :at time changes' do
      start_at = publisher.start_at
      new_start_at = start_at + 1.week

      allow(Reactor::Event).to receive(:reschedule)

      publisher.start_at = new_start_at
      publisher.save!

      expect(Reactor::Event).to have_received(:reschedule).with(:begin,
        a_hash_including(
          at: new_start_at,
          actor: publisher,
          was: start_at,
          additional_info: 'curtis was here'
        )
      )
    end

    it 'reschedules an event when the :watch field changes' do
      ring_time = publisher.ring_timeout
      new_start_at = publisher.start_at + 1.week
      new_ring_time = new_start_at + 30.seconds

      allow(Reactor::Event).to receive(:reschedule)

      publisher.start_at = new_start_at
      publisher.save!

      expect(Reactor::Event).to have_received(:reschedule).with(:ring,
        a_hash_including(
          at: new_ring_time,
          actor: publisher,
          was: ring_time
        )
      )
    end

    context 'conditional firing' do
      before do
        Sidekiq::Testing.fake!
        Sidekiq::Worker.clear_all
        TestSubscriber.create! event_name: :conditional_event_on_save
        publisher
        job = Reactor::Event.jobs.detect do |job|
          job['class'] == 'Reactor::Event' && job['args'].first == 'conditional_event_on_save'
        end
        @job_args = job['args']
      end

      after do
        Sidekiq::Testing.inline!
      end

      it 'calls the subscriber when if is set to true' do
        publisher.we_want_it = true
        publisher.start_at = 3.day.from_now
        allow(Reactor::Event).to receive(:perform_at)
        publisher.save!
        expect(Reactor::Event).to have_received(:perform_at).with(publisher.start_at, :conditional_event_on_save, anything())

        Reactor::Event.perform(@job_args[0], @job_args[1])
      end

      it 'does not call the subscriber when if is set to false' do
        publisher.we_want_it = false
        publisher.start_at = 3.days.from_now
        publisher.save!

        expect{ Reactor::Event.perform(@job_args[0], @job_args[1]) }.to_not change{ Sidekiq::Queues.jobs_by_queue.values.flatten.count }
      end

      it 'keeps the if intact when rescheduling' do
        old_start_at = publisher.start_at
        publisher.start_at = 3.day.from_now
        allow(Reactor::Event).to receive(:publish)
        expect(Reactor::Event).to receive(:publish).with(:conditional_event_on_save, {
          at: publisher.start_at,
          actor: publisher,
          target: nil,
          was: old_start_at,
          if: anything
        })
        publisher.save!
      end

      it 'keeps the if intact when scheduling' do
        start_at = 3.days.from_now
        allow(Reactor::Event).to receive(:publish)
        expect(Reactor::Event).to receive(:publish).with(:conditional_event_on_save, {
          at: start_at,
          actor: anything,
          target: nil,
          if: anything
        })
        Publisher.create!(start_at: start_at)
      end
    end

    it 'supports immediate events (on create) that get fired once' do
      Reactor.with_subscriber_enabled(Reactor::Subscriber) do
        TestSubscriber.create! event_name: :bell
        publisher
        expect(TestSubscriber.class_variable_get(:@@called)).to be_truthy
        TestSubscriber.class_variable_set(:@@called, false)
        publisher.start_at = 1.day.from_now
        publisher.save
        expect(TestSubscriber.class_variable_get(:@@called)).to be_falsey
      end
    end

    it 'does publish an event scheduled for the future' do
      Reactor.enable_test_mode_subscriber Reactor::Subscriber
      Reactor.enable_test_mode_subscriber Publisher
      TestSubscriber.create! event_name: :begin
      Publisher.create!(pet: pet, start_at: Time.current + 1.week)

      expect(TestSubscriber.class_variable_get(:@@called)).to be_truthy

      Reactor.disable_test_mode_subscriber Reactor::Subscriber
      Reactor.disable_test_mode_subscriber Publisher
    end
  end
end
