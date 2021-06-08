#!/usr/bin/env ruby
#
# This code is modified from an example script that I used here:
#
#   https://github.com/ManageIQ/manageiq/pull/20670
#
# And the example ansible script is a slightly modified version of the
# `sleep.yml` found here:
#
#   https://github.com/ansible/test-playbooks/blob/master/sleep.yml
#

require 'optparse'

OptionParser.new do |opt|
  opt.banner = "Usage: #{File.basename $0} [options] [PLAYBOOK_FILE]"

  opt.separator ""
  opt.separator "Runs a playbook using `ansible_runner` using the MIQ/CFME"
  opt.separator "`Ansible::Runner` lib."
  opt.separator ""
  opt.separator "This script is intended to run on an appliance and from the"
  opt.separator "`/var/www/miq/vmdb` directory, and requires necessary"
  opt.separator "ruby libraries from relative directories."
  opt.separator ""
  opt.separator "Example Usage:"
  opt.separator ""
  opt.separator "  $ ssh root@my_miq_appliance.example.com"
  opt.separator "  root@my_miq_appliance # vmdb"
  opt.separator "  root@my_miq_appliance # ./ansible_runner_runner_runner.rb"
  opt.separator "  root@my_miq_appliance # ./ansible_runner_runner_runner.rb /path/to/custom/playbook.yml"
  opt.separator ""
  opt.separator "Options"

  opt.on("-h", "--help", "Show this message") do
    puts opt
    exit
  end
end.parse!

require 'pathname'

class Rails
  def self.root
    Pathname.new(Dir.pwd)
  end
end

class Vmdb
  module Logging
  end
end

$: << Rails.root.join("lib").to_s

require 'awesome_spawn'
require 'ansible/runner'
require 'ansible/content'
require 'ansible/runner/response'
require 'ansible/runner/response_async'
require 'tmpdir'
require 'tempfile'
require 'active_support/all'

playbook_file = nil
playbook_path = ARGV[0]

if playbook_path.nil?
  playbook_file  = Tempfile.new
  playbook_path  = playbook_file.path
  sleep_playbook = <<-SLEEP_YML.gsub(/^ {4}/, "")
    ---

    - name: 'Test playbook to sleep for a specified interval'
      hosts: all
      gather_facts: false
      vars:
        sleep_interval: 5

      tasks:
        - name: sleep for a specified interval
          command: sleep '{{ sleep_interval }}'
  SLEEP_YML

  playbook_file.write sleep_playbook
  playbook_file.close
end

response = Ansible::Runner.run_async({}, {}, sleep_playbook)
puts response.base_dir


if ARGV[0].nil? # wait for playbook if using default playbook
  puts response.running?

  200.times do
    puts response.running?
  end
end
