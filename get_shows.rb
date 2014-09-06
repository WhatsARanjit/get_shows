#!/usr/bin/ruby
require 'yaml'
require 'rss'
require 'open-uri'

# Load configuration file
begin
  config_params = YAML.load_file('/etc/get_shows.yaml')
  rescue 
    $stderr.print "\033[31mCould not find file /etc/get_shows.yaml\033[0m\n"
  raise
end

config_params['shows'].each do |show,hash|
  baseurl  = hash['torrent_url'] ? hash['torrent_url'] : config_params['torrent_url']
  options  = hash['torrent_options'] ? hash['torrent_options'] : config_params['torrent_options']
  url      = baseurl + '/' + URI::encode(show.to_s) + '/' + options
  dest_dir = hash['dest_dir'] ? hash['dest_dir'] : config_params['dest_dir']
  open(url) do |rss|
    feed = RSS::Parser.parse(rss)
    feed.items.each do |item|
      puts "Item #{item.title}"
    end
  end
end

