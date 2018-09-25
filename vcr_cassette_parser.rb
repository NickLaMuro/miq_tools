#!/usr/bin/env ruby

cassettes = ARGV

require 'yaml'

results = {}

cassettes.each do |file|
  data = YAML.load_file(file)
  data["http_interactions"].each do |request|
    method            = request["request"]["method"]
    results[method] ||= {}
    type              = results[method]

    uri         = request["request"]["uri"]
    type[uri] ||= []
    type[uri]  << request["response"]["body"]["string"].size
  end
end

results.keys.each do |request_method|

  pad = results[request_method].keys.map!(&:length).max
  puts
  puts "#{request_method.capitalize} #{pad}"
  puts "-----------------------"

  results[request_method].each do |uri, request_sizes|
    puts "#{uri.rjust(pad)}:  "                           \
         "COUNT - #{request_sizes.count.to_s.rjust(4)}, " \
         "AVG SIZE - #{request_sizes.sum / request_sizes.count}"
  end
  puts
end
