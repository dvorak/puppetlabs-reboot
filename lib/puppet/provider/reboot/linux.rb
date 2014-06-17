require 'puppet/type'
require 'open3'

Puppet::Type.type(:reboot).provide :linux do
  confine :kernel => :linux
  defaultfor :kernel => :linux

  def self.shutdown_command
     'shutdown'
  end

  commands :shutdown => shutdown_command

  def when
  end

  def when=
  end

  def self.instances
    []
  end

  def cancel_transaction
    Puppet::Application.stop!
  end

  def reboot
    if @resource[:apply] != :finished
      cancel_transaction
    end

    shutdown_path = command(:shutdown)
    unless shutdown_path
      raise ArgumentError, "The shutdown command was not found."
    end

    timeout_in_minutes = (@resource[:timeout].to_i / 60).ceil
    shutdown_cmd = [shutdown_path, '-r', "+#{timeout_in_minutes}", "\"#{@resource[:message]}\""].join(' ')
    async_shutdown(shutdown_cmd)
  end

  def async_shutdown(shutdown_cmd)
    if Puppet[:debug]
      $stderr.puts(shutdown_cmd)
    end

    # execute a ruby process to shutdown after puppet exits
    watcher = File.join(File.dirname(__FILE__), 'linux', 'watcher.rb')
    if not File.exists?(watcher)
      raise ArgumentError, "The watcher program #{watcher} does not exist"
    end

    Puppet.debug("Launching 'ruby #{watcher}'")
    system("ruby '#{watcher}' #{Process.pid} #{@resource[:catalog_apply_timeout]} '#{shutdown_cmd}'")
    Puppet.debug("Launched process #{$?.pid}")
  end

end
