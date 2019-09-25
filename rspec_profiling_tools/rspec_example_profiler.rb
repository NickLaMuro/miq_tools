puts "loading rspec_benchmark_setup.rb"
require "rubygems"
require "stackprof"
require "fileutils"

gem "rspec", "~> 3.6.0"

FileUtils.mkdir_p "rspec_profiles"
last_run = Dir["rspec_profiles/*"].sort.last.to_s.split("/").last.to_i

RSPEC_PROF_RUN_DIR = File.join "rspec_profiles", '%05d' % (last_run + 1)
FileUtils.mkdir_p RSPEC_PROF_RUN_DIR

require "rspec/core"
require "rspec/core/example"

module RSpec
  module Core
    class Example
      alias __old_run run
      alias __old_finish finish

      def run(example_group_instance, reporter)
        StackProf.start(:mode => :wall, :raw => true)
        __old_run(example_group_instance, reporter)
      end

      def finish(reporter)
        __old_finish(reporter)
        StackProf.stop
        example_file_name  = execution_result.run_time.to_i.to_s
        example_file_name += get_location_for_filename
        StackProf.results(File.join(RSPEC_PROF_RUN_DIR, example_file_name))
      end

      private

      def get_location_for_filename
        RSpec.configuration.backtrace_formatter.backtrace_line(
          location.to_s.split(':in `block').first
        ).gsub(/\//, "%").gsub(/:/, "-")
      end
    end
  end
end
