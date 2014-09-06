#!/usr/bin/ruby
require 'yaml'
require 'rss'
require 'open-uri'

# Load configuration file
begin
  config_params = YAML.load_file('/etc/config_params.yaml')
  rescue 
    $stderr.print "\033[31mCould not find file /etc/config_params.yaml\033[0m\n"
  raise
end

config_params['shows'].each do |show,hash|
  torrent_url = hash['torrent_url'] ? hash['torrent_url'] : config_params['torrent_url']
  puts torrent_url
end

#open(url) do |rss|
#  feed = RSS::Parser.parse(rss)
#  feed.items.each do |item|
#    puts "Item #{item.title}"
#  end
#end
