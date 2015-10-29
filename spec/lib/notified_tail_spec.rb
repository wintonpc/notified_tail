require 'rspec'
require 'securerandom'
require 'notified_tail'

describe NotifiedTail do
  describe '#tail' do
    let!(:seek_end) { false }
    let!(:force_poll) { false }

    shared_examples 'tail -f' do
      let!(:lines) { [] }
      let!(:fn) { SecureRandom.uuid }
      after(:each) { File.delete(fn) }

      it 'tails a growing file, line by line' do

        append(fn, "before\ntailing\n")

        watcher = Thread.start do
          notifier = NotifiedTail.new
          notifier.tail(fn, seek_end: seek_end, force_poll: force_poll) do |line|
            puts "saw #{line.inspect}"
            expect(line).to eql expected.first
            expected.shift
            notifier.stop if expected.empty?
          end
        end
        sleep(0.25) # let the notifier start up

        append(fn, "one\n")
        append(fn, "two\nthree\n")
        append(fn, "gr")
        append(fn, "ow")
        append(fn, "ing\nlonger\n")
        append(fn, "line with words\n")
        watcher.join
      end

      def append(fn, text)
        File.open(fn, 'a') { |f| f.print(text) }
        sleep(0.1)
      end
    end

    shared_examples 'tail -f -n 9999PB' do
      let!(:expected) { ['before', 'tailing', 'one', 'two', 'three', 'growing', 'longer', 'line with words'] }
      it_behaves_like 'tail -f'
    end

    shared_examples 'tail -f -n 0' do
      let!(:expected) { ['one', 'two', 'three', 'growing', 'longer', 'line with words'] }
      it_behaves_like 'tail -f'
    end

    context 'when not seeking to the end' do
      it_behaves_like 'tail -f -n 9999PB'
    end

    context 'when the platform does not support notifications' do
      before(:each) { allow(NotifiedTail).to receive(:get_ruby_platform).and_return('wha??') }
      it_behaves_like 'tail -f -n 9999PB'
    end

    context 'when seeking to the end' do
      let!(:seek_end) { true }
      it_behaves_like 'tail -f -n 0'
    end

    context 'when forcing polling' do
      let!(:force_poll) { true }
      before(:each) do
        expect(INotify::Notifier).to_not receive(:new) if defined?(INotify::Notifier)
        expect(KQueue::Queue).to_not receive(:new) if defined?(KQueue::Queue)
      end
      it_behaves_like 'tail -f -n 9999PB'
    end

  end
end
