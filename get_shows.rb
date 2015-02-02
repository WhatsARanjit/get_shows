#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'rss'
require 'open-uri'
require 'optparse'
require 'colorize'

options = {:debug => false, :nodown => false}
parser = OptionParser.new do|opts|
  opts.on('-d', '--debug', 'Turns debug on') do |value|
    options[:debug] = true
  end
  opts.on('-n', '--no-download', 'Reports new links without beginning download') do |value|
    options[:nodown] = true
  end
  opts.on('-c', '--no-color', 'Removes color output') do |value|
    options[:nocolor] = true
  end
  opts.on('-h', '--help', 'Displays help') do |help|
    puts opts
    exit
  end
end
parser.parse!

debug     = options[:debug]
nodown    = options[:nodown]
$coloroff = options[:nocolor]

def outputs (string, color, coloroff = $coloroff)
  output = coloroff ? string: string.colorize(color.to_sym)
end

# Get current time for delay comparison
time = Time.now
done = []
puts outputs("=>Start: #{time}", 'green')

# Load configuration file
begin
  config_params = YAML.load_file('/etc/get_shows.yaml')
rescue 
  $stderr.print "Error: Could not find file /etc/get_shows.yaml\n".red
  puts outputs("=>End: #{Time.now}", 'red')
  exit 1
end

config_params['shows'].each do |show,hash|
  showname = show.to_s
  puts outputs("==>#{showname}", 'cyan') if debug
  uri          = hash['torrent_uri']     ? hash['torrent_uri']      : config_params['torrent_uri']
  options      = hash['torrent_options'] ? hash['torrent_options']  : config_params['torrent_options']
  url          = hash['torrent_url']     ? hash['torrent_url']      : config_params['torrent_url']
  headers      = hash['headers']         ? hash['headers']          : config_params['headers']
  season       = hash['season']          ? hash['season']           : config_params['season']
  searchstring = season                  ? "#{showname} S#{season}" : showname
  dest_dir     = hash['dest_dir']        ? hash['dest_dir']         : config_params['dest_dir']
  delay        = hash['delay']           ? hash['delay']            : config_params['delay']
  max_age      = hash['max_age']         ? hash['max_age']          : config_params['max_age']
  cmd          = hash['torrent_cmd']     ? hash['torrent_cmd']      : config_params['torrent_cmd']

  url          = url.gsub(/%uri/, uri).gsub(/%showname/, URI::encode(searchstring)).gsub(/%options/, options)
  puts outputs("==>#{url}", 'cyan') if debug

  # Rescue a failure from a bad URL or a 404 if not torrent is available
  begin
    open(url, headers) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|

        # Make a user-friendly, repeatable version of the title
        title = item.title.gsub(/\./, ' ').gsub(/(#{showname}\s?(?:S\d+)?(?:E\d+)?).*/i, '\1')
        dest_file = "#{dest_dir}/*#{title}*"
        
        # Don't do the following if the title is already in the done array
        if Dir.glob(dest_file).empty?
          puts outputs("===>#{title}", 'cyan') if debug

          # Calculate the age of the torrent relative to the delay
          pubdate = Date.parse "#{item.pubDate} (#{time.getlocal.zone})"
          now     = Date.parse time.strftime('%a, %d %b %Y %X +0000 (%Z)')
          age     = now - pubdate

          # If the torrent is old enough
          if (age > delay) and (age < max_age)
            puts outputs("===>Passes age check [#{age}]: #{now} - #{pubdate}", 'cyan') if debug

            # Extract the magnet URL
            begin
              magnet = item.enclosure.to_s.match(/url="(.*)"/) [1]
            rescue
              puts outputs("===>Warning: Could not find URL in #{item.enclosure.to_s}", 'yellow')
            else
              puts outputs("===>\"#{item.title}\" available from #{magnet}", 'green') if nodown
              doit = %x{ #{cmd} #{magnet} } unless nodown
              if $?.exitstatus.to_i < 1

                # If torrent add works, add to done array and output info
                puts outputs("===>Downloading \"#{item.title}\" from #{magnet}", 'green')
                done << title

              end unless nodown # END: checking if torrent command succeeded

            end # END: Rescue to see if we could get a URL
          else
            puts outputs("===>Fails age check [#{age}]: #{now} - #{pubdate}", 'cyan') if debug
          end # END: Age test
        else
          puts outputs("===>Fails disk check: #{Dir.glob(dest_file)}", 'cyan') if debug
        end unless done.include? title # END: if file does not already exist

        # Mock add to array if not actually downloaded
        done << title if nodown

      end # END: RSS iteration
      puts outputs("==>Done with feed", 'green')
    end # END: open(url) vblock
  rescue Exception => e
    raise e.message
    puts outputs("==>Notice: No RSS Feed for show \"#{show}\"\n", 'green')
  end
end # END: Shows hash

puts outputs("=>End: #{Time.now}", 'green')
