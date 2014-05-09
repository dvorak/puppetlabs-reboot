require 'syslog'

class Watcher
  require 'tempfile'

  attr_reader :pid, :timeout, :command

  def initialize(argv)
    @pid = argv[0].to_i
    @timeout = argv[1].to_i
    @command = argv[2]

    Syslog.open("puppet-reboot-watcher", Syslog::LOG_PERROR, Syslog::LOG_DAEMON)
  end

  def wait_for_exit
    # Can't call waitpid, since it's not our child process, instead we send it
    # signal 0 which will just return if the process is alive, and return
    # Errno::ESRCH if it's not found.  We keep doing that until the parent
    # dies, then we know we're safe to proceed.

    start_time = Time.now
    while true do
      begin
        Process.kill(0, @pid)
      rescue Errno::ESRCH
        return :exited
      end

      return :timeout if Time.now - start_time  > @timeout
      sleep 0.1
    end
  end

  def execute
    case wait_for_exit
    when :exited
      log_message("Process completed; executing '#{command}'.")
      system(command)
    when :timeout
      log_message("Timed out waiting for process to exit; reboot aborted.")
    else
      log_message("Failed to wait on the process (#{get_last_error}); reboot aborted.")
    end
  end

  def log_message(message)
    message = [ message ] unless message.kind_of? Array
    message.each do |line|
      Syslog.log(Syslog::LOG_NOTICE, line)
    end
  end
end

if __FILE__ == $0
  exit!(0) if fork
  Process::setsid
  exit!(0) if fork
  Dir::chdir('/')

  watcher = Watcher.new(ARGV)
  begin
    watcher.execute
  rescue Exception => e
    watcher.log_message(e.message)
    watcher.log_message(e.backtrace)
  end
end
