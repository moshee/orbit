#!/usr/bin/env ruby -w
# encoding: UTF-8

%w{json net/http socket libxml cgi htmlentities}.each { |r| require r }
load 'triggers.rb'

# command prefixes
$prefixes = ["]", "."]
# matches hostmasks of people who are allowed to use maintenance etc features
$admin_hostmasks = /moshee@mo\.sh\.ee|24.16.155.210/
$api_keys = {
	:imgur		=>	"86479b06ff689612409190829dd46576",
	:dictionary	=>	"ukgjitziiotr3nb3xwo99uzv0iovuc3pwk8fe8yxwr"
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

class RBot
	@@copy = 0
	
	def initialize server, port=6667, nick, user, channels
		@socket = TCPSocket.new(server,port)
		@filename = __FILE__
		
		# these instance variables are accessible from all triggers in Triggers
		@nick, @channels, @current_copy, @user = nick, channels, (@@copy += 1), user
	end
	
	def cmd str
		puts "--> #{str}"
		@socket.send "#{str}\r\n", 0
	end
	
	def say str, chan = @target
		str.each_line do |line|
			cmd "PRIVMSG #{chan} :#{line}"
		end
	end
	
	def onoez! problem = ''
		reply = "I am error"
		reply << " (#{problem})" unless problem.empty?
		say reply
	end

#	Two options for regexes.
#
#	/(:\S+\s)?(\S+|\d{3})\s((#|&)?[\w\\\[\]{}\^`\|][\w\-\\\[\]{}\^`\|]*\s)?{1,2}:(.+)/
#	-	matches all lines including numerical responses (\d{3}) (still in progress)
#	
#	/(:\S+)? ?([A-Z]+) (#?[\w\-\\\[\]{}\^`\|]* )?:(.+)/
#	-	matches only regular commands (PRIVMSG, PING, NICK, NOTICE, ...)

	def handle(line)
		begin
			line.match(/(:\S+)? ?([A-Z]+) (#?[\w\-\\\[\]{}\^`\|]* )?:(.+)/)
			@source, @raw_command, @target, @message = $1, $2, $3, $4
			@nick = @source[/[^~!]+/] if @source != nil
			self.send @raw_command.downcase! if @raw_command and @message
		rescue NoMethodError
			puts "*** [RBot.handle] NoMethodError: #{$!}"
		rescue ArgumentError
			say "Argument Error: #{$!}"
			puts $!.backtrace
		end
	end
	
	def privmsg
		# public channel message (lol irc protocol)
		if ['#','&'].include? @target[0] and $prefixes.include? @message.slice! 0
			command, lol, args = @message.partition ' '
			self.send command, args
		end
	end
	
	def ping
		cmd "PONG :#{@message}"
	end
	
	def notice
	end
	
	def permission
		return true if @source.match($admin_hostmasks)
	end
	
	def connect
		# login
		cmd "USER RBOT-#{@current_copy} 0 0 :#{@user}"
		cmd "NICK #{@nick}"
		@channels.each { |channel| cmd "JOIN #{channel}" }
		
		# main loops
		# read from socket, write to stdout, and handle IRC input
		read_thread = Thread.new do
			while true
				begin			
					ready = select([@socket], nil, nil)
					redo if !ready
					break if @socket == nil
					line = @socket.gets
					puts "<-- #{line.chomp!}"
					handle line
				rescue Exception
					puts "*** [Main Loop] #{$!}"
					retry
				end
			end
		end
		# write to socket from stdin
		write_thread = Thread.new do
			while true
				cmd gets.chomp
			end
		end
		
		read_thread.join
		write_thread.join
	end
	
	private
	
	include Triggers
end

this = RBot.new("irc.rizon.net", 6667, "mosfet`rb", "Ruby-Passivated Junction", ["#moshee"])
this.connect

#END { File::open('tell.txt', 'w') { |f| f.write $tell.to_json } }