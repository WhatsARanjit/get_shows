# get_shows.rb

This is a script designed to manage a list of shows,
and grab them off your favorite torrent site.

# Configuration
The configuration is managed in /etc/get_shows.yaml.
A sample is included in the repository.  Most of the
configurations can be set globally and then overriden
by the show-level if necessary.

`torrent_url`:<br />
THe torrent_url will be used to construct the URL
where get_shows finds an RSS feed, containing
information to search for available torrents.

`torrent_options`:</br />
This value will be URI parameters added to your 
RSS search URL.  These may include sorting parameters,
user filters, or other indexes.

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

`dest_dir`:<br />
Get_shows will search for a filename based on the
torrents available to see if you've already downloaded
the intended file.  Provide the directory here.

`shows`:<br />
This has is where you will specify at the least, the
name of the shows you are concerned with.  For example,
you can simple say 'Full House' or if you are concerned
with a certain season, use 'Full House S03'.  If you
are concerned with a certain episode, get even more
detailed with 'Full House S03E14'.
