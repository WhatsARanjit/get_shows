#!/usr/bin/ruby
require 'yaml'
require 'rss'
require 'open-uri'
require 'optparse'

options = {:debug => false, :nodown => false}
parser = OptionParser.new do|opts|
  opts.on('-d', '--debug', 'Turns debug on') do |value|
    options[:debug] = true
  end
  opts.on('-n', '--no-download', 'Reports new links without beginning download') do |value|
    options[:nodown] = true
  end
  opts.on('-h', '--help', 'Displays help') do |help|
    puts opts
    exit
  end
end
parser.parse!

debug  = options[:debug]
nodown = options[:nodown]

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
  puts showname if debug
  uri          = hash['torrent_uri'] ? hash['torrent_uri']         : config_params['torrent_uri']
  options      = hash['torrent_options'] ? hash['torrent_options'] : config_params['torrent_options']
  url          = hash['torrent_url'] ? hash['torrent_url']         : config_params['torrent_url']
  season       = hash['season'] ? hash['season']                   : config_params['season']
  searchstring = season ? "#{showname} S#{season}"                 : showname
  url          = url.gsub(/%uri/, uri).gsub(/%showname/, URI::encode(searchstring)).gsub(/%options/, options)
  dest_dir     = hash['dest_dir'] ? hash['dest_dir']               : config_params['dest_dir']
  delay        = hash['delay'] ? hash['delay']                     : config_params['delay']
  max_age      = hash['max_age'] ? hash['max_age']                 : config_params['max_age']
  cmd          = hash['torrent_cmd'] ? hash['torrent_cmd']         : config_params['torrent_cmd']
  puts url if debug

  # Rescue a failure from a back URL or even a 404 if not torrent is available
  begin
    rss_check = open(url)
  rescue Exception
    puts "Notice: No RSS Feed for show \"#{show}\"\n"
    good = false
  else
    good = true 
  end

  # Start parsing the RSS if a good URL
  open(url) do |rss|
    feed = RSS::Parser.parse(rss)
    feed.items.each do |item|

      # Make a user-friendly,` repeatable version of the title
      #title = item.title.gsub(/\./, ' ').gsub(/(#{showname}[a-z0-9]+\b).*/i, '\1')
      title = item.title.gsub(/\./, ' ').gsub(/(#{showname}\s?(?:S\d+)?(?:E\d+)?).*/i, '\1')
      check = %x{ /bin/find #{dest_dir} -iname "*#{title}*" | /bin/grep -q "#{title}" }

      # Don't do the following if the title is already in the done array
      if $?.exitstatus.to_i > 0
        puts title if debug
        puts "Passes on disk check [#{$?.exitstatus.to_i}]: /bin/find #{dest_dir} -iname \"*#{title}*\" | /bin/grep -q \"#{title}\"" if debug

        # Calculate the age of the torrent relative to the delay
        pubdate = Date.parse "#{item.pubDate} (#{time.getlocal.zone})"
        now     = Date.parse time.strftime('%a, %d %b %Y %X +0000 (%Z)')
        age     = now - pubdate

        # If the torrent is old enough
        if (age > delay) and (age < max_age)
          puts "Passes age check [#{age}]: #{now} - #{pubdate}" if debug

          # Extract the magnet URL
          begin
            magnet = item.enclosure.to_s.match(/url="(.*)"/) [1]
          rescue
            puts "Warning: Could not find URL in #{item.enclosure.to_s}"
          else
            puts "\"#{item.title}\" available from #{magnet}" if nodown
            doit = %x{ #{cmd} #{magnet} } unless nodown
            if $?.exitstatus.to_i < 1

              # If torrent add works, add to done array and output info
              puts "Downloading \"#{item.title}\" from #{magnet}"
              done << title

            end unless nodown # END: checking if torrent command succeeded

          end # END: Rescue to see if we could get a URL
        end # END: Age test
        puts "Fails age check [#{age}]: #{now} - #{pubdate}" if debug
      end unless done.include? title # END: if file does not already exist

      # Mock add to array if not actually downloaded
      done << title if nodown

    end # END: Iterating through items
  end if good # END: open(url) vblock
end # END: Shows hash

puts "==>End: #{Time.now}"
