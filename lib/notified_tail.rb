# Tail lines in a given file
# Inspired by http://rubyforadmins.com/reading-growing-files
class NotifiedTail

  # Yields complete lines, one at a time.
  # Works even if file doesn't exist yet.
  # @param file_path [String] The file to tail
  # @option opts [Boolean] seek_end (true)
  #   If true, seeks to the end of the file before reporting lines.
  #   Otherwise, reports all lines starting at the beginning of the file.
  def self.tail(file_path, opts={}, &on_line)
    new.tail(file_path, opts, &on_line)
  end

  def tail(filename, opts, &on_line)
    @stopped = false
    seek_end = opts.fetch(:seek_end, true)
    sleep(0.25) until File.exists?(filename)
    File.open(filename) do |file|
      unreported_line = ''
      if seek_end
        file.seek(0, IO::SEEK_END)
      else
        read_and_report_lines(file, unreported_line, &on_line)
      end
      when_modified(filename) { read_and_report_lines(file, unreported_line, &on_line) }
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

  def when_modified(file_path)
    case NotifiedTail.get_ruby_platform
    when /bsd/, /darwin/
      require 'rb-kqueue'
      @queue = KQueue::Queue.new
      @queue.watch_file(ARGV.first, :extend) { yield }
      @queue.run
    when /linux/
      require 'rb-inotify'
      @queue = INotify::Notifier.new
      @queue.watch(file_path, :modify) { yield }
      @queue.run
    else
      last_mtime = File.mtime(file_path)
      until @stopped do
        sleep(0.5)
        mtime = File.mtime(file_path)
        yield if mtime != last_mtime # use != instead of > to mitigate DST complications
        last_mtime = mtime
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
