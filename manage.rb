#!/usr/bin/env ruby
require 'fileutils'

PORT_PREFIX=2380
XDG_CONFIG_HOME = ENV['XDG_CONFIG_HOME'] || "#{ENV['HOME']}/.config"
UNIT_DIR="#{XDG_CONFIG_HOME}/systemd/user"
FileUtils.mkdir_p UNIT_DIR

class Commander
  def method_missing(*)
    help
  end

  def help(*args)
    puts "Commands:"
    puts
    puts "  help\t\t\tthis help text"
    puts "  add\t[host] [port]\tAdd new config"
    puts "  list\t\t\tList configs"
    puts "  remove\t[host]\tRemove config"
    puts "  stop\t[host,...|all]\tStop hosts"
    puts "  update\t\t\t Update all hosts"
  end

  def add(*args)
    return help unless args.size == 2
    host, port = args
    proxy_port = "#{PORT_PREFIX}#{port}"
    proxy_proxy_port = "#{PORT_PREFIX+1}#{port}"

    write_file "ssh-socks.socket", host, proxy_port
    write_file "ssh-socks.service", host, proxy_proxy_port
    write_file "ssh-socks-proxy.service", host, proxy_proxy_port

    systemctl('daemon-reload')
    systemctl("enable ssh-socks_#{host}.socket")
    systemctl("start ssh-socks_#{host}.socket")

    puts "Your proxy to #{host} is ready at 127.0.0.1:#{proxy_port}"
  end

  def list(*args)
    return help unless args.empty?
    puts "Installed hosts:"
    puts
    each_host do |host, port|
      puts "  * #{host} (#{port})"
    end
  end

  def remove(*args)
    return help unless args.size == 1
    host = args.first

    unless File.exists?(path_to('ssh-socks.socket', host))
      puts "No proxy for #{host} found!"
      return
    end

    systemctl("stop ssh-socks_#{host}.socket")
    stop(host)
    systemctl("disable ssh-socks_#{host}.socket")
    FileUtils.remove path_to('ssh-socks.socket', host)
    FileUtils.remove path_to('ssh-socks.service', host)
    FileUtils.remove path_to('ssh-socks-proxy.service', host)
  end

  def stop(*args)
    available_hosts = each_host.map(&:first)
    if args.empty? || args.first == 'all'
      hosts = available_hosts
    else
      hosts = available_hosts & args
    end

    hosts.each do |host|
      systemctl("stop ssh-socks-proxy_#{host}.service")
      systemctl("stop ssh-socks_#{host}.service")
    end
  end

  def update(*args)
    return help unless args.empty?
    each_host do |host, port|
      remove(host)
      add(host, port.sub(PORT_PREFIX.to_s, ''))
    end
  end

  private

  def write_file name, host, port
    File.write path_to(name, host),
               replace_vars(File.read("templates/#{name}"),
                            host: host, port: port)
  end

  def replace_vars input, vars
    input.gsub(/%(#{Regexp.union(vars.keys.map(&:to_s))})%/) {
      vars[$1] || vars[$1.to_sym]
    }
  end

  def systemctl command
    system "/usr/bin/systemctl --user #{command}"
  end

  def path_to(name, host)
    prefix, type = name.split '.'
    "#{UNIT_DIR}/#{prefix}_#{host}.#{type}"
  end

  def each_host
    return enum_for(__method__) unless block_given?

    Dir["#{UNIT_DIR}/ssh-socks_*.socket"].each do |path|
      host = File.basename(path)[/ssh-socks_(.+).socket/, 1]
      port = File.readlines(path).find {|line| line.start_with? 'ListenStream' }.chomp.split(':')[1]
      yield [host, port]
    end
  end
end


commander = Commander.new
if ARGV.empty?
  commander.help
else
  commander.public_send(*ARGV)
end
