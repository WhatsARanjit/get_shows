# get_shows.rb

This is a script designed to manage a list of shows,
and grab them off your favorite torrent site. The
scripts expects a standard RSS format for torrent
listings.  See `sample.xml` as an example.

# Command line
```
Usage: get_shows [options]
    -d, --debug                      Turns debug on
    -n, --no-download                Reports new links without beginning download
    -c, --no-color                   Removes color output
    -h, --help                       Displays help
    -v, --version                    Display current version
```

# Configuration
The configuration is managed in `/etc/get_shows.yaml`.
A sample is included in the repository at
`sample_get_shows.yaml`.  Most of the configurations
can be set globally and then overriden by the
show-level if necessary.

`torrent_uri`:<br />
THe torrent_uri will be used to construct the URL
where get_shows finds an RSS feed, containing
information to search for available torrents.

`torrent_options`:</br />
This value will be URI parameters added to your 
RSS search URL.  These may include sorting parameters,
user filters, or other indexes.

`torrent_url`:<br />
The torrent_url is a dynamic URL that is generated from
the variables `%uri` (torrent_url), `%showname` (name of
show in hash), and `%options` (torrent_options). For
example, you can set it to `'%uri/%showname/%options'`.

`headers`:<br />
Headers can be passed as a `headers` hash. Each key/value
will be passed into the HTTP call for the RSS feed.  For
example, pass a User-Agent or a Referer.

`season`:<br />
The season is a 2 digit number that will be used in the
search URL of specified.  The format is for the search
URL is `'%uri/%showname S##/%options'`.

`torrent_cmd`:<br />
Get_shows is torrent-agnostic.  That is, indicate the
command line tool to use to add a torrent to your
server.  This can be found in the software's
documentation, whether it be TransmissionBT or
uShare.

`delay`:<br />
Delay is a number of days to wait before downloading
a torrent.  For example, if you'd like to wait 2 weeks
before downloading any new torrents (for a reason of
your choosing), set this value to 14.

`max_age`:<br />
Max_age is a number of days before considering a 
torrent too old for download.  For example, if you'd
like to avoid downloading torrents older than 2 weeks,
set this value to 14.

`dest_dir`:<br />
Get_shows will search for a filename based on the
torrents available to see if you've already downloaded
the intended file.  Provide the directory here.

`shows`:<br />
This is where you will specify at the least, the
name of the shows you are concerned with.  For example,
you can simple say 'Full House' or if you are concerned
with a certain season, use 'Full House S03'.  If you
are concerned with a certain episode, get even more
detailed with 'Full House S03E14'.
