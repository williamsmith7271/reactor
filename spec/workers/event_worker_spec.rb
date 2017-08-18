require 'spec_helper'

class SourceSubscriber
  include Reactor::Subscribable

  def self.fire_worker(event)
    :method_called
  end
end

class FailingEventWorker < Reactor::Workers::EventWorker
end

class MyEventWorker < Reactor::Workers::EventWorker
  self.source = SourceSubscriber
  self.action = :fire_worker
  self.async  = true
  self.delay  = 0
  self.deprecated = false
end

class MyBlockWorker < Reactor::Workers::EventWorker
  self.source = SourceSubscriber
  self.action = lambda { |event| :block_ran }
  self.async  = true
  self.delay  = 0
  self.deprecated = false
end

class MyDelayedWorker < Reactor::Workers::EventWorker
  self.source = SourceSubscriber
  self.action = :fire_worker
  self.async  = true
  self.delay  = 1 # seconds
  self.deprecated = false
end

class MyImmediateWorker < Reactor::Workers::EventWorker
  self.source = SourceSubscriber
  self.action = :fire_worker
  self.async  = false
  self.delay  = 0
  self.deprecated = false
end

describe Reactor::Workers::EventWorker do
  let(:event_name) { :fire_worker }
  let(:event_data) { Hash[my_event_data: true] }

  describe '.configured?' do
    context 'for unconfigured class' do
      subject { FailingEventWorker.configured? }

      it { is_expected.to eq(false) }
    end

    context 'for configured class' do
      subject { MyEventWorker.configured? }

      it { is_expected.to eq(true) }
    end
  end

  describe '.perform_where_needed?' do
    context 'for delayed worker' do
      let(:klass) { MyDelayedWorker }
      subject { klass.perform_where_needed(event_data) }

      it 'uses perform_in to delay execution' do
        expect(klass).to receive(:perform_in).with(1, event_data)
        subject
      end
    end

    context 'for async workers' do
      let(:klass) { MyEventWorker }
      subject { klass.perform_where_needed(event_data) }

      it 'uses perform_async to execute wherever' do
        expect(klass).to receive(:perform_async).with(event_data)
        subject
      end
    end

    context 'for immediate workers' do
      let(:klass) { MyImmediateWorker }
      subject { klass.perform_where_needed(event_data) }

      it 'creates and executes new instance' do
        expect_any_instance_of(klass).to receive(:perform).with(event_data)
        subject
      end
    end
  end

  describe '#perform' do
    let(:klass) { MyEventWorker }
    subject { klass.new.perform(event_data) }

    context 'for unconfigured worker' do
      let(:klass) { FailingEventWorker }

      it 'raises an error' do
        expect { subject }.to raise_error(Reactor::UnconfiguredWorkerError)
      end
    end

    context 'when should_perform? is false' do
      let(:klass) { MyEventWorker }

      it 'returns :__perform_aborted__' do
        expect(subject).to eq(:__perform_aborted__)
      end
    end

    context 'when should_perform? is true' do
      before { allow_any_instance_of(klass).to receive(:should_perform?).and_return(true) }

      it 'calls class method by symbol' do
        expect(subject).to eq(:method_called)
      end

      context 'for block workers' do
        let(:klass) { MyBlockWorker }
        it { is_expected.to eq(:block_ran) }
      end
    end
  end

end
