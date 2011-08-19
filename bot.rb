#!/usr/bin/env ruby -w
# encoding: UTF-8

%w[json net/http socket libxml cgi htmlentities optparse].each { |r| require r }

OptionParser.new do |args|
	args.on('-s', '--server [SERVER]', 'Connect to server SERVER') { |server| $server = server }
	args.on('-p', '--port [PORT]', 'Use port PORT') { |port| $port = port.to_i }
	args.on('-n', '--nick [NICK]', 'Use nick NICK') { |nick| $nick = nick }
	args.on('-u', '--user [USER]', 'Use realname USER') { |user| $user = user }
	args.on('-j', '--join ["channel1 [channel2 ...]"]', 'Join channels') { |chans| $chans = chans.split ' ' }
end.parse!

$server	||= "irc.rizon.net"
$port		||= 6667
$nick		||= "rfet"
$user		||= "Ruby-Passivated Junction"
$chans	||= []

# command prefixes
$prefixes = ["]", "."]

# matches hostmasks of people who are allowed to use maintenance etc features
$admin_hostmasks = //

$api_keys = {

}

# makes the google dictionary api work properly
$byte_killer = Iconv.new 'UTF-8//IGNORE', 'UTF-8'

# for the tell command
begin
	File::open('tell.txt') { |f| $tell = JSON.parse f.read }
rescue Errno::ENOENT
	File.new('tell.txt', 'w') { |f| f.write '{}'}
	retry
rescue JSON::ParserError
	
end

load 'irc.rb'
load 'commander.rb'
load 'rbot.rb'

# Currently, you have to start one ruby process per connected server. I'm not 
# sure if I will change this behavior yet.
this = RBot.new($server, $port, $nick, $user, $chans)
this.connect

# at_exit { File::open('tell.txt', 'w') { |f| f.write $tell.to_json } }