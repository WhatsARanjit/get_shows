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

# Get current time for delay comparison
time = Time.now
done = []

config_params['shows'].each do |show,hash|
  showname = show.to_s
  baseurl  = hash['torrent_url'] ? hash['torrent_url'] : config_params['torrent_url']
  options  = hash['torrent_options'] ? hash['torrent_options'] : config_params['torrent_options']
  url      = baseurl + '/' + URI::encode(showname) + '/' + options
  dest_dir = hash['dest_dir'] ? hash['dest_dir'] : config_params['dest_dir']
  delay    = hash['delay'] ? hash['delay'] : config_params['delay']
  open(url) do |rss|
    feed = RSS::Parser.parse(rss)
    feed.items.each do |item|
      # Make a user-friendly repeatable version of the title
      title = item.title.gsub(/\./, ' ').gsub(/(#{showname}[a-z0-9]+\b).*/i, '\1')
      check = %x{ /bin/find #{dest_dir} -iname "*#{title}*" | /bin/grep -q "#{title}" }
      # Don't do the following if the title is already in the done array
      ( 
        pubdate = Date.parse "#{item.pubDate} (#{time.getlocal.zone})"
        now     = Date.parse time.strftime('%a, %d %b %Y %X +0000 (%Z)')
        age     = now - pubdate
        if age > delay 
          done << title
          puts "Downloading #{item.title}" 
        end
      ) unless done.include? title
    end
  end
end

