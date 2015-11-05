require 'fileutils'
require 'rims'
require 'tmpdir'
require 'yaml'

require_relative '../../spec/support/fixtures'

module TestEmailServerHelpers
  def project_root
    File.expand_path('../..', File.dirname(__FILE__))
  end

  # This file holds configuration
  # and transient data (PID and temp directory)
  # Keys are Symbols
  def config_filename
    File.join(project_root, 'rims.yaml')
  end

  def default_config
    connection = fixture('connection')
    port = connection[:server_options][:port]
    {
      imap_port: port,
      imap_host: connection[:server],
      username: connection[:username],
      password: connection[:password],
    }
  end

  def initialize_config
    @config = default_config
  end

  def load_config
    @config = YAML.load(File.read(config_filename))
  end

  def create_working_directory
    @config[:base_dir] = Dir.mktmpdir(nil, 'tmp')
  end

  def save_config
    File.open(config_filename, 'w') { |f| f.write @config.to_yaml }
  end

  def delete_config
    File.unlink(config_filename)
  end

  def delete_working_directory
    base_dir = @config.delete(:base_dir)
    FileUtils.rm_rf base_dir
  end

  def start_server
    pid = fork do
      SimpleCov.at_exit { } if defined? SimpleCov
      RIMS::Cmd.run_cmd(['daemon', 'start', "-f#{config_filename}"])
    end
    Process.waitpid pid
  end

  def stop_server
    pid = fork do
      SimpleCov.at_exit { } if defined? SimpleCov
      RIMS::Cmd.run_cmd(['daemon', 'stop', "-f#{config_filename}"])
    end
    Process.waitpid pid
  end
end

namespace :test do
  namespace :email_server do
    include TestEmailServerHelpers

    desc 'Start the email server process'
    task :start do
      initialize_config
      create_working_directory
      save_config
      start_server
      log = File.join(@config[:base_dir], 'imap.log')
      sleep 0.01 while not File.exist?(log)
      sleep 0.1 while not File.read(log).include?('start server')
    end

    desc 'Stop the email server process'
    task :stop do
      stop_server
      load_config
      delete_working_directory
      delete_config
    end

    directory 'tmp'
  end
end
