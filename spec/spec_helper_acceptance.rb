# frozen_string_literal: true

# require 'beaker-rspec/spec_helper'
# require 'beaker-rspec/helpers/serverspec'
# require 'beaker/puppet_install_helper'

require 'serverspec'
require 'solid_waffle'
include SolidWaffle

require 'rspec/retry'

begin
  require 'pry'
rescue LoadError # rubocop:disable Lint/HandleExceptions for optional loading
end

# This method allows a block to be passed in and if an exception is raised
# that matches the 'error_matcher' matcher, the block will wait a set number
# of seconds before retrying.
# Params:
# - max_retry_count - Max number of retries
# - retry_wait_interval_secs - Number of seconds to wait before retry
# - error_matcher - Matcher which the exception raised must match to allow retry
# Example Usage:
# retry_on_error_matching(3, 5, /OpenGPG Error/) do
#   apply_manifest(pp, :catch_failures => true)
# end
def retry_on_error_matching(max_retry_count = 3, retry_wait_interval_secs = 5, error_matcher = nil)
  try = 0
  begin
    try += 1
    yield
  rescue StandardError => e
    raise unless try < max_retry_count && (error_matcher.nil? || e.message =~ error_matcher)
    sleep retry_wait_interval_secs
    retry
  end
end

if ENV['TARGET_HOST'].nil? || ENV['TARGET_HOST'] == 'localhost'
  puts 'Running tests against this machine !'
  if Gem.win_platform?
    set :backend, :cmd
  else
    set :backend, :exec
  end
else
  # load inventory
  inventory_hash = inventory_hash_from_inventory_file
  node_config = config_from_node(inventory_hash, ENV['TARGET_HOST'])

  if target_in_group(inventory_hash, ENV['TARGET_HOST'], 'ssh_nodes')
    set :backend, :ssh
    options = Net::SSH::Config.for(host)
    options[:user] = node_config.dig('ssh', 'user') unless node_config.dig('ssh', 'user').nil?
    options[:port] = node_config.dig('ssh', 'port') unless node_config.dig('ssh', 'port').nil?
    options[:password] = node_config.dig('ssh', 'password') unless node_config.dig('ssh', 'password').nil?
    options[:verify_host_key] = Net::SSH::Verifiers::Null.new unless node_config.dig('ssh', 'host-key-check').nil?
    host = if ENV['TARGET_HOST'].include?(':')
             ENV['TARGET_HOST'].split(':').first
           else
             ENV['TARGET_HOST']
           end
    set :host,        options[:host_name] || host
    set :ssh_options, options
    set :request_pty, true
  elsif target_in_group(inventory_hash, ENV['TARGET_HOST'], 'winrm_nodes')
    require 'winrm'

    set :backend, :winrm
    set :os, family: 'windows'
    user = node_config.dig('winrm', 'user') unless node_config.dig('winrm', 'user').nil?
    pass = node_config.dig('winrm', 'password') unless node_config.dig('winrm', 'password').nil?
    endpoint = "http://#{ENV['TARGET_HOST']}:5985/wsman"

    opts = {
      user: user,
      password: pass,
      endpoint: endpoint,
      operation_timeout: 300,
    }

    winrm = WinRM::Connection.new opts
    Specinfra.configuration.winrm = winrm
  end
end

# run_puppet_install_helper unless ENV['BEAKER_provision'] == 'no'

# RSpec.configure do |c|
#   # Add exclusive filter for Windows untill all the windows functionality is implemented
#   c.filter_run_excluding win_broken: true

#   # Project root
#   proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

#   # Readable test descriptions
#   c.formatter = :documentation

#   # show retry status in spec process
#   c.verbose_retry = true
#   # show exception that triggers a retry if verbose_retry is set to true
#   c.display_try_failure_messages = true

#   # Configure all nodes in nodeset
#   c.before :suite do
#     # Install module and dependencies
#     hosts.each do |host|
#       next unless not_controller(host)
#       copy_module_to(host, source: proj_root, module_name: 'docker')
#       # Due to RE-6764, running yum update renders the machine unable to install
#       # other software. Thus this workaround.
#       if fact_on(host, 'operatingsystem') == 'RedHat'
#         on(host, 'mv /etc/yum.repos.d/redhat.repo /etc/yum.repos.d/internal-mirror.repo')
#         on(host, 'rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm')
#       end
#       on(host, 'yum update -y -q') if fact_on(host, 'osfamily') == 'RedHat'

#       on host, puppet('module', 'install', 'puppetlabs-stdlib', '--version', '4.24.0'), acceptable_exit_codes: [0, 1]
#       on host, puppet('module', 'install', 'puppetlabs-apt', '--version', '4.4.1'), acceptable_exit_codes: [0, 1]
#       on host, puppet('module', 'install', 'puppetlabs-translate', '--version', '1.0.0'), acceptable_exit_codes: [0, 1]
#       on host, puppet('module', 'install', 'puppetlabs-powershell', '--version', '2.1.5'), acceptable_exit_codes: [0, 1]
#       on host, puppet('module', 'install', 'puppetlabs-reboot', '--version', '2.0.0'), acceptable_exit_codes: [0, 1]

#       # net-tools required for netstat utility being used by some tests
#       if fact_on(host, 'osfamily') == 'RedHat' && fact_on(host, 'operatingsystemmajrelease') == '7'
#         on(host, 'yum install -y net-tools device-mapper')
#       end

#       if fact_on(host, 'osfamily') == 'Debian'
#         on(host, 'apt-get install net-tools')
#       end
#       docker_compose_content_v3 = <<-EOS
# version: "3.4"
# x-images:
#   &default-image
#   alpine:3.8
# services:
#   compose_test:
#     image: *default-image
#     command: /bin/sh -c "while true; do echo hello world; sleep 1; done"
#       EOS
#       docker_compose_override_v3 = <<-EOS
# version: "3.4"
# x-images:
#   &default-image
#   debian:stable-slim
# services:
#   compose_test:
#     image: *default-image
#     command: /bin/sh -c "while true; do echo hello world; sleep 1; done"
#         EOS
#       docker_stack_override_v3 = <<-EOS
# version: "3.4"
# x-images:
#   &default-image
#   debian:stable-slim
# services:
#   compose_test:
#     image: *default-image
#     command: /bin/sh -c "while true; do echo hello world; sleep 1; done"
#         EOS
#       docker_compose_content_v3_windows = <<-EOS
# version: "3"
# services:
#   compose_test:
#     image: hello-world:nanoserver
#     command: cmd.exe /C "ping 8.8.8.8 -t"
# networks:
#   default:
#     external:
#       name: nat
#       EOS
#       docker_compose_override_v3_windows = <<-EOS
# version: "3"
# services:
#   compose_test:
#     image: hello-world:nanoserver-sac2016
#     command: cmd.exe /C "ping 8.8.8.8 -t"
# networks:
#   default:
#     external:
#       name: nat
#       EOS
#       docker_stack_content_windows = <<-EOS
# version: "3"
# services:
#   compose_test:
#     image: hello-world:nanoserver
#     command: cmd.exe /C "ping 8.8.8.8 -t"
#       EOS
#       docker_stack_override_windows = <<-EOS
# version: "3"
# services:
#   compose_test:
#     image: hello-world:nanoserver-sac2016
#       EOS
#       if fact_on(host, 'osfamily') == 'windows'
#         create_remote_file(host, '/tmp/docker-compose-v3.yml', docker_compose_content_v3_windows)
#         create_remote_file(host, '/tmp/docker-stack.yml', docker_stack_content_windows)
#         create_remote_file(host, '/tmp/docker-compose-override-v3.yml', docker_compose_override_v3_windows)
#         create_remote_file(host, '/tmp/docker-stack-override.yml', docker_stack_override_windows)
#       else
#         create_remote_file(host, '/tmp/docker-compose-v3.yml', docker_compose_content_v3)
#         create_remote_file(host, '/tmp/docker-stack.yml', docker_compose_content_v3)
#         create_remote_file(host, '/tmp/docker-compose-override-v3.yml', docker_compose_override_v3)
#         create_remote_file(host, '/tmp/docker-stack-override.yml', docker_stack_override_v3)
#       end

#       next unless fact_on(host, 'osfamily') == 'windows'
#       win_host = only_host_with_role(hosts, 'default')
#       retry_on_error_matching(60, 5, %r{connection failure running}) do
#         @windows_ip = win_host.ip
#       end
#       apply_manifest_on(host, "class { 'docker': docker_ee => true, extra_parameters => '\"insecure-registries\": [ \"harbor.cummins.com:5000\" ]' }")
#       docker_path = '/cygdrive/c/Program Files/Docker'
#       host.add_env_var('PATH', docker_path)
#       host.add_env_var('TEMP', 'C:\Users\Administrator\AppData\Local\Temp')
#       puts 'Waiting for box to come online'
#       sleep 300
#     end
#   end
# end
