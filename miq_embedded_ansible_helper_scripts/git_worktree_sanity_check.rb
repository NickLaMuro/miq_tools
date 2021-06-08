#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require 'io/console'
require 'securerandom'
require 'tmpdir'

options             = {}
INVALID_CRED_SEARCH = "ERR:  Must provide a valid id or name for a ScmCredential in the system"

OptionParser.new do |opt|
  opt.banner = "Usage: #{File.basename $0} [options] GIT_URL"

  opt.separator ""
  opt.separator "This script takes either a name (-n/--name) or ID (-i/--id)"
  opt.separator "for a given ScmCredential in your system to validate against"
  opt.separator "a given git URL to confirm it works with both the `git` CLI"
  opt.separator "and the MIQ/CFME codebase"
  opt.separator ""
  opt.separator "This script is intended to run on an appliance and from the"
  opt.separator "`/var/www/miq/vmdb` directory, and requires necessary"
  opt.separator "ruby libraries from relative directories."
  opt.separator ""
  opt.separator "Example Usage:"
  opt.separator ""
  opt.separator "  $ ssh root@my_miq_appliance.example.com"
  opt.separator "  root@my_miq_appliance # vmdb"
  opt.separator "  root@my_miq_appliance # ./git_worktree_test.rb --name personal_key example.com:org/repo.git"
  opt.separator ""
  opt.separator "Options"

  opt.on("-iID",   "--id=ID",     Integer, "ID of the ScmCredential to use") do |id|
    options[:scm_credential_id] = id
  end

  opt.on("-nNAME", "--name=NAME", String,  "Name of the ScmCredential to test with") do |name|
    options[:scm_credential_name] = name
  end

  opt.on("-h",     "--help",               "Show this message") do
    puts opt
    exit
  end
end.parse!

puts "loading MIQ/CFME environment..."
require File.expand_path("config/environment")

FileUtils.mkdir_p GitRepository::GIT_REPO_DIRECTORY

where_clause    = {:id => options[:scm_credential_id]}     if options[:scm_credential_id]
where_clause    = {:name => options[:scm_credential_name]} if options[:scm_credential_name]
cred_type       = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ScmCredential
credential      = cred_type.where(where_clause).first

if credential.nil?
  warn INVALID_CRED_SEARCH
  exit 1
end

cli_dir         = File.join(GitRepository::GIT_REPO_DIRECTORY, "repo-#{SecureRandom.uuid}")
git_dir         = File.join(GitRepository::GIT_REPO_DIRECTORY, "repo-#{SecureRandom.uuid}")
git_url         = ARGV[0]  # Example: "github.com:NickLaMuro/ansible-tower-samples.git"
git_username    = credential.userid || "git"
ssh_key_file    = Tempfile.new

ssh_key_file.write credential.auth_key
ssh_key_file.close

worktree_params = {
  :url               => "#{git_username}@#{git_url}",
  :path              => git_dir,
  :clone             => true,
  :username          => git_username,
  :ssh_private_key   => credential.auth_key
}

begin

  #### Using `git` cli ... #####

  puts "Sanity check: first clone via the `git` cli..."

  `ssh-agent bash -c 'ssh-add #{ssh_key_file.path}; git clone #{worktree_params[:url]} #{cli_dir}'`
  raise "error with cli clone..." unless $? == 0
  puts "Clone successful!  Displaying repo entries..."
  puts

  cli_worktree = GitWorktree.new(:path => cli_dir)
  puts cli_worktree.entries("").map { |e| "  #{e}" }
  puts
  puts "press any key to continue..."

  STDIN.noecho(&:getch)

  #### Using GitWorktree (MIQ + Rugged) ... #####

  worktree = GitWorktree.new(worktree_params)

  puts "Cloned to #{git_dir}..."
  puts "Repo entries..."
  puts

  puts worktree.entries("").map { |e| "  #{e}" }
  puts
  puts "press any key to continue..."

  STDIN.noecho(&:getch)
ensure
  FileUtils.rm_rf git_dir
  FileUtils.rm_rf cli_dir
  ssh_key_file.unlink
end
