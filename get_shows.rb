#!/usr/bin/ruby
require 'yaml'
require 'rss'
require 'open-uri'

# Get current time for delay comparison
time = Time.now
done = []
puts "==>Start: #{time}"

# Load configuration file
begin
  config_params = YAML.load_file('/etc/get_shows.yaml')
rescue 
  $stderr.print "\033[31mError: Could not find file /etc/get_shows.yaml\033[0m\n"
  exit 1
end

config_params['shows'].each do |show,hash|
  showname = show.to_s
  uri      = hash['torrent_uri'] ? hash['torrent_uri'] : config_params['torrent_uri']
  options  = hash['torrent_options'] ? hash['torrent_options'] : config_params['torrent_options']
  url      = hash['torrent_url'] ? hash['torrent_url'] : config_params['torrent_url']
  url      = url.gsub(/%uri/, uri).gsub(/%showname/, URI::encode(showname)).gsub(/%options/, options)
  dest_dir = hash['dest_dir'] ? hash['dest_dir'] : config_params['dest_dir']
  delay    = hash['delay'] ? hash['delay'] : config_params['delay']
  cmd      = hash['torrent_cmd'] ? hash['torrent_cmd'] : config_params['torrent_cmd']
  begin
    rss_check = open(url)
  rescue Exception
    puts "Notice: No RSS Feed for show \"#{show}\"\n"
    good = false
  else
    good = true 
  end
  open(url) do |rss|
    feed = RSS::Parser.parse(rss)
    feed.items.each do |item|
      # Make a user-friendly repeatable version of the title
      title = item.title.gsub(/\./, ' ').gsub(/(#{showname}[a-z0-9]+\b).*/i, '\1')
      check = %x{ /bin/find #{dest_dir} -iname "*#{title}*" | /bin/grep -q "#{title}" }
      # Don't do the following if the title is already in the done array
      if $?.exitstatus.to_i > 0
        pubdate = Date.parse "#{item.pubDate} (#{time.getlocal.zone})"
        now     = Date.parse time.strftime('%a, %d %b %Y %X +0000 (%Z)')
        age     = now - pubdate
        if age > delay 
          magnet = item.enclosure.to_s.match(/url="(.*)"/) [1]
          doit = %x{ #{cmd} #{magnet} }
          if $?.exitstatus.to_i < 1
            puts "Downloading \"#{item.title}\" from #{magnet}"
            done << title
          end
        end
      end unless done.include? title 
    end
  end if good
end

puts "==>Start: #{Time.now}"
