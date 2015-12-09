#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'optparse'
require 'colorize'
require 'net/http'
require 'rss'

class ConfigParams
  attr_reader :show_hash

  def initialize(config)
    # Load configuration file
    begin
      config_yaml = YAML.load_file(config)
    rescue 
      STDERR.print "Error: Could not find file /etc/get_shows.yaml\n".red
      exit 1
    end

    @show_hash = parse_show(config_yaml)

  end

  private

  def parse_show(yaml)
    show_hash = Hash.new
    yaml['shows'].each do |show, prop|
      show_hash[show] = Hash.new
      yaml.each do |k,v|
        next if k == 'shows'
        show_hash[show][k] = prop[k] || v
      end
      show_hash[show]['season'] = prop['season'] if prop['season']
    end
    show_hash
  end

end

class CmdOptions
  attr_reader :debug, :nodown, :coloroff

  def initialize
    options   = parse_options
    @debug    = options[:debug]
    @nodown   = options[:nodown]
    @coloroff = options[:nocolor]
  end

  def outputs (string, color = false, coloroff = @coloroff)
    output = coloroff ? string : string.colorize(color.to_sym)
  end

  private

  def parse_options
    options = {
      :debug  => false,
      :nodown => false,
    }
    parser = OptionParser.new do |opts|
      opts.on(
        '-d',
        '--debug',
        'Turns debug on'
      ) do |value|
        options[:debug] = true
      end
      opts.on(
        '-n',
        '--no-download',
        'Reports new links without beginning download'
      ) do |value|
        options[:nodown] = true
      end
      opts.on(
        '-c',
        '--no-color',
        'Removes color output'
      ) do |value|
        options[:nocolor] = true
      end
      opts.on(
        '-h',
        '--help',
        'Displays help'
      ) do |help|
        puts opts
        exit
      end
      opts.on(
        '-v',
        '--version',
        'Display current version'
      ) do |version|
        puts 'get_shows v2.0'
        exit
      end
    end
    parser.parse!
    options
  end

end

class Show
  attr_reader :showname
  attr_reader :rss_url
  
  def initialize(show, params)
    # Construct URL
    @showname       = show.to_s
    torrent_uri     = params['torrent_uri']
    torrent_options = params['torrent_options']
    torrent_url     = params['torrent_url']
    season          = params['season'] if params['season']
    searchstring    = season ? "#{@showname} season:#{season}" : @showname
    @rss_url        = create_rss_url(
                        torrent_url,
                        torrent_uri,
                        searchstring,
                        torrent_options
                      )
    # HTTP Options
    @headers        = params['headers']
  end

  def get_rss(rss_url)
    uri                = URI.parse(rss_url)
    begin
      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request          = Net::HTTP::Get.new(uri.request_uri, @headers)
      response         = http.request(request)
    rescue Timeout::Error,
           Errno::EINVAL,
           Errno::ECONNRESET,
           EOFError,
           Net::HTTPBadResponse,
           Net::HTTPHeaderSyntaxError,
           Net::ProtocolError => e
      STDERR.puts "ERROR: #{e.message}".red
    else
      if response.code == '200'
        # Check for compression
        if response.header['Content-Encoding'].eql?('gzip')
          sio  = StringIO.new(response.body)
          gz   = Zlib::GzipReader.new(sio)
          page = gz.read
        else
          page = response.body
        end
        page
      end
    end
  end

  def parse_rss(html)
    begin
      RSS::Parser.parse(html)
    rescue
      false
    end
  end

  private

  def create_rss_url(pattern, uri, searchstring, options)
    sw_uri      = pattern.gsub(/%uri/, uri)
    sw_showname = sw_uri.gsub(/%showname/, URI::encode(searchstring))
    sw_options  = sw_showname.gsub(/%options/, options)
  end

end

class Episode
  attr_reader :title
  attr_reader :torrent_cmd

  def initialize(showname, item, params)
    @showname    = showname
    # Filtering options
    @title       = item.title
    @enclosure   = item.enclosure
    @time        = Time.now
    @pubdate     = Date.parse "#{item.pubDate} (#{@time.getlocal.zone})"
    @torrent_cmd = params['torrent_cmd']
    @delay       = params['delay']
    @max_age     = params['max_age']
    @dest_dir    = params['dest_dir']
  end

  def friendly_title(title)
    title.gsub(/\./, ' ').gsub(/(#{@showname}\s?(?:S\d+)?(?:E\d+)?).*/i, '\1')
  end

  def dot_title(title)
    friendly_title(title).gsub(/\s/, '.')
  end

  def dest_file
    "#{@dest_dir}/**/*#{friendly_title(@title)}*"
  end

  def dest_file_dot
    "#{@dest_dir}/**/*#{dot_title(@title)}*"
  end

  def file_exists?
    #puts Dir.glob(dest_file, File::FNM_CASEFOLD)
    #puts Dir.glob(dest_file_dot, File::FNM_CASEFOLD)
    Dir.glob(dest_file, File::FNM_CASEFOLD).empty? and
    Dir.glob(dest_file_dot, File::FNM_CASEFOLD).empty?
  end

  def age_check?
    (age > @delay) and (age < @max_age)
  end

  def get_magnet_url
    begin
      magnet = @enclosure.to_s.match(/url="(.*)"/) [1]
    rescue
      false
    else
      magnet
    end
  end

  private

  def age
    (Date.parse(@time.strftime('%a, %d %b %Y %X +0000 (%Z)')) - @pubdate).to_i
  end

end

opts = CmdOptions.new
puts opts.outputs("=>Start: #{Time.now}", 'green')

configparams = ConfigParams.new('/etc/get_shows.yaml')
puts opts.outputs('=>Loaded configuration file', 'green')

shows = configparams.show_hash
shows.each do |title, props|
  # Keep track of done shows
  done = []
  # Initialize show
  sh = Show.new(title, props)
  puts opts.outputs("==>#{sh.showname}", 'green')
  # Grab HTML
  html = sh.get_rss(sh.rss_url)
  puts opts.outputs("===>#{sh.rss_url}", 'cyan') if opts.debug
  # Parse HTML into RSS
  rss = sh.parse_rss(html)
  next unless rss
  puts opts.outputs("==>RSS parsed for #{sh.showname}", 'green')
  # Iterate through RSS
  rss.items.each do |item|
    ep    = Episode.new(sh.showname, item, props)
    title = ep.friendly_title(item.title)
    # Check if done already
    unless done.include? title.downcase
      puts opts.outputs("===>#{title}", 'green')
    else
      puts opts.outputs("===>#{title} already done, skipping", 'cyan') if opts.debug
      next
    end
    # Destination files
    #puts opts.outputs("===>#{ep.dest_file}", 'cyan') if opts.debug
    #puts opts.outputs("===>#{ep.dest_file_dot}", 'cyan') if opts.debug
    # File check
    unless ep.file_exists?
      puts opts.outputs('===>File exists, skipping', 'cyan') if opts.debug
      next
    end
    # Not too new or old
    unless ep.age_check?
      puts opts.outputs('===>Fails age check, skipping', 'cyan') if opts.debug
      next
    end
    # Able to parse out magnet URL
    magnet = ep.get_magnet_url
    unless magnet
      puts opts.outputs('===>Warning: Could not find magent URL', 'yellow')
      next
    end
    unless opts.nodown
      puts opts.outputs("===>\"#{title}\" available from #{magnet}", 'green')
      doit = %x{ #{ep.torrent_cmd} #{magnet} }
      if $?.exitstatus.to_i < 1
        # If torrent add works, add to done array and output info
        puts opts.outputs("===>Downloading \"#{title}\"", 'light_blue')
        puts opts.outputs("===>Magnet URL: #{magnet}", 'cyan') if opts.debug
        done << title.downcase
      end
    else
      # Mock add to array if not actually downloaded
      done << title.downcase
    end
    puts opts.outputs("===>Done with #{title}", 'green')
  end
  puts opts.outputs("==>Done with #{sh.showname}", 'green')
end

puts opts.outputs("=>End: #{Time.now}", 'green')
