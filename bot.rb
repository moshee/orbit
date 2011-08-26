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
$admin_hostmasks = /moshee@mo\.sh\.ee|24.16.155.210/

$api_keys = {
	:imgur			=>	"",
	:dictionary	=>	""
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

load 'rbot.rb'

# Currently, you have to start one ruby process per connected server. I'm not 
# sure if I will change this behavior yet.
this = RBot.new($server, $port, $nick, $user, $chans)


this.bind('reload') do
	# close and reopen script (*nix only)
	admin? do
		cmd 'QUIT :reloading'
		exit!
		system "screen -U ./#{__FILE__}"
	end
end


this.bind('help') do |args|
	if args.nil?
		say "Triggers: \x02calc\x02 (c), \x02imgur\x02 (ir, i), \x02weather\x02 (w), \x02translate\x02 (tl, t), \x02stocks\x02 (s), \x02define\x02 (d), \x02thesaurus\x02 (synonyms, th), \x02tell\x02"
	else
		# do stuff with args
	end
end


this.bind('die') do
	admin? do
		cmd 'QUIT :okay ;_;'
		exit!
	end
end


this.bind('rt') do
	# reload triggers.rb only (this file)
	admin? { load __FILE__ }
end


this.bind('raw') do |command|
	admin? { cmd command }
end


this.bind('please') do |expression|
	admin? { eval expression }
end


this.bind('calc', 'c') do |args|
	response = JSON.parse(Net::HTTP.get(URI.parse("http://www.google.com/ig/calculator?hl=en&q=#{CGI.escape(args)}")).gsub(/([^,{]+):/,"\"\\1\":"))
	if ['', '0'].include? response['error']
		rhs = ($byte_killer.iconv response['rhs']).gsub(/ x26#215;\s10x3csupx3e(\-?\d+)x3c\/supx3e/,"e\\1").gsub(/x3csupx3e(\-?\d+)x3c\/supx3e/,"\^\\1")
		say "#{response['lhs']} = #{rhs}"
	else
		onoez! response['error']
	end
end

this.connect

# at_exit { File::open('tell.txt', 'w') { |f| f.write $tell.to_json } }