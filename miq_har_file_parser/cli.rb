#!/usr/bin/env ruby

require 'optparse'
require_relative 'parser'

module HarFile
  class CLI
    # Sub command for the CLI (required)
    attr_accessor :action

    def self.option_parser options
      OptionParser.new do |opt|
        opt.banner = "Usage: #{File.basename $0} subcmd [options] [HAR_FILE]"

        opt.separator ""
        opt.separator "Parses the given HAR (Http ARchive) file and allows for"
        opt.separator "printing or generating a rails runner script from the"
        opt.separator "generated data, for use in creating a single script for" 
        opt.separator "reproducing of a set of requests)"
        opt.separator ""
        opt.separator "Sub Commands"
        opt.separator ""
        opt.separator "  print"
        opt.separator "  generate"
        opt.separator ""
        opt.separator "Options"

        opt.on "-i", "--input=FILE",        "Input HAR file (default: STDIN)" do |input|
          options[:input] = input
        end

        opt.on "-o", "--output=FILE",       "Command output (default: STDOUT)" do |output|
          options[:output] = output
        end

        opt.separator ""
        opt.separator "Generate Options"

        opt.on "-a", "--[no-]auto-profile", "Auto set benchmark headers (default: false)" do |auto_profile|
          options[:auto_profile] = auto_profile
        end

        opt.on "-t", "--threshold=VAL",     "Time, in ms, that deservse a profile (default: 10000)" do |threshold|
          options[:threshold] = threshold.to_i
        end

        opt.on "-h", "--help",        "Show this message" do
          puts opt
          exit
        end
      end
    end

    def self.run args = ARGV
      new(args).run
    end

    def initialize args = ARGV
      @options = {}
      option_parser.parse! args

      @action          = ARGV.shift.to_s.to_sym
      @options[:input] = ARGV.shift 
      @parser          = HarFile::Parser.new(@options)
    end

    def run
      case action
      when :print    then @parser.summary
      when :generate then @parser.generate_runner
      else
        puts ">>>>> ERR: invalid sub-command! <<<<<"
        puts
        puts option_parser.help
      end
    end

    private

    def option_parser
      self.class.option_parser @options
    end
  end
end

HarFile::CLI.run if __FILE__ == $PROGRAM_NAME
