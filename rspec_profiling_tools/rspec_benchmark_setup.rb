puts "loading rspec_benchmark_setup.rb"
require "rubygems"
require "stackprof"

gem "rspec", "~> 3.6.0"

# require "rspec/core/runner"
# 
# # Patches RSpec running prior to loading it to only profile up to the setup.
# # This will cause a slightly less than real world times, but for the most part,
# # this should simulate everything that needs to be loaded.
# module RSpec
#   module Core
#     class Runner
#       def run(err, out)
#         setup(err, out)
#         StackProf.stop
#         StackProf.results("rspec_startup.stackprof")
#         puts "stopping stackprof..."
#         run_specs(@world.ordered_example_groups).tap do
#           persist_example_statuses
#         end
#       end
#     end
#   end
# end


# require "rspec/core/reporter"
# 
# module RSpec
#   module Core
#     class Reporter
#     def report(expected_example_count)
#       start(expected_example_count)
# 			StackProf.stop
# 			StackProf.results("rspec_startup.stackprof")
# 			puts "stopping stackprof..."
#       begin
#         yield self
#       ensure
#         finish
#       end
#     end
# 	end
# end

require "rspec/core"
require "rspec/core/configuration"
 
module RSpec
  module Core
    class Configuration
      def with_suite_hooks
        return yield if dry_run?

        begin
          run_suite_hooks("a `before(:suite)` hook", @before_suite_hooks)
          StackProf.stop
          StackProf.results("rspec_startup.stackprof")
          puts "stopping stackprof..."
          yield
        ensure
          run_suite_hooks("an `after(:suite)` hook", @after_suite_hooks)
        end
      end
		end
	end
end


puts "starting stackprof..."
StackProf.start(:mode => :wall, :raw => true)

# # Simulate the main parts of RubyGem's `bundle` binstub
# version = ">= 0.a"
# 
# if ARGV.first
#   str = ARGV.first
#   str = str.dup.force_encoding("BINARY") if str.respond_to? :force_encoding
#   if str =~ /\A_(.*)_\z/ and Gem::Version.correct?($1) then
#     version = $1
#     ARGV.shift
#   end
# end
# 
# puts "loading bundler..."
# gem "bundler"
# load Gem.bin_path("bundler", "bundle", version)

gem "bundler"
require "bundler/setup"
require "rspec/core"
status = RSpec::Core::Runner.run(ARGV)
exit status if status != 0
