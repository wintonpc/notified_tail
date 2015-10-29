# Tail lines in a given file
# Inspired by http://rubyforadmins.com/reading-growing-files
class NotifiedTail

  attr_reader :file_path

  # Yields complete lines, one at a time.
  # Works even if file doesn't exist yet.
  # @param file_path [String] The file to tail
  # @option opts [Boolean] seek_end (true)
  #   If true, seeks to the end of the file before reporting lines.
  #   Otherwise, reports all lines starting at the beginning of the file.
  # @option opts [Boolean] force_poll (false)
  #   Poll even if inotify or kqueue are available
  def self.tail(file_path, opts={}, &on_line)
    new.tail(file_path, opts, &on_line)
  end

  def tail(file_path, opts, &on_line)
    @file_path = file_path
    @stopped = false
    seek_end = opts.fetch(:seek_end, true)
    @force_poll = opts.fetch(:force_poll, false)
    sleep(0.25) until File.exists?(file_path)
    File.open(file_path) do |file|
      unreported_line = ''
      if seek_end
        file.seek(0, IO::SEEK_END)
      else
        read_and_report_lines(file, unreported_line, &on_line)
      end
      when_modified(file_path) { read_and_report_lines(file, unreported_line, &on_line) }
    end
  end

  def stop
    @queue.stop if @queue
    @queue = nil
    @stopped = true
  end

  private

  def read_and_report_lines(file, unreported_line, &on_line)
    loop do
      c = file.readchar
      if line_ending?(c)
        on_line.call(unreported_line.dup)
        unreported_line.clear
        while (c = file.readchar) && line_ending?(c) do; end
      end
      unreported_line << c
    end
  rescue EOFError
    # done for now
  end

  def when_modified(file_path, &block)
    if @force_poll
      poll(file_path, &block)
    else
      case NotifiedTail.get_ruby_platform
      when /bsd/, /darwin/
        require 'rb-kqueue'
        @queue = KQueue::Queue.new
        @queue.watch_file(file_path, :extend) { block.call }
        @queue.run
      when /linux/
        require 'rb-inotify'
        @queue = INotify::Notifier.new
        @queue.watch(file_path, :modify) { block.call }
        @queue.run
      else
        poll(file_path, &block)
      end
    end
  end

  def poll(file_path, &block)
    last_mtime = File.mtime(file_path)
    last_notify_time = nil
    until @stopped do
      sleep(0.5)
      mtime = File.mtime(file_path)
      changed = mtime != last_mtime
      if changed || last_notify_time == nil || (Time.now - last_notify_time) > 5
        last_mtime = mtime
        last_notify_time = Time.now
        block.call
      end
    end
  end

  def self.get_ruby_platform
    RUBY_PLATFORM
  end

  def line_ending?(c)
    c == "\n" || c == "\r"
  end
end
