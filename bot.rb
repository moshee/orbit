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
		@botnick, @channels, @current_copy, @user = nick, channels, (@@copy += 1), user
	end
	
	def cmd str
		puts "--> #{str}"
		@socket.send "#{str}\r\n", 0
	end
	
	def say str, target = @target
		str.each_line { |line| cmd "PRIVMSG #{target} :#{line}" }
	end
	
	def action str, target = @target
		say "\0ACTION #{str}\0", target
	end
	
	def ctcp str, target = @target
		say "\1#{str}\1", target
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
			puts $!.backtrace
		rescue ArgumentError
			say "Argument Error: #{$!}"
			puts $!.backtrace
		end
	end
	
	def privmsg
		# public channel message (lol irc protocol)
		if ['#','&'].include?(@target[0]) and @message.sub!(/^#{@botnick}\s*(,|:)\s*/, '') or $prefixes.include?(@message.slice! 0)
			command, lol, args = @message.partition ' '
			self.send command, args
		end
	end
	
	def ping
		cmd "PONG :#{@message}"
	end
	
	def notice
	end
	
	
	def owner? &block
		if @source.match($admin_hostmasks)
			block.call if not block == nil
			return true
		else
			action "slaps #{@nick}\'s hand away from the big red button"
			return false
		end
	end
	
	def connect
		# login
		cmd "USER RBOT-#{@current_copy} 0 0 :#{@user}"
		cmd "NICK #{@botnick}"
		@channels.each { |channel| cmd "JOIN #{channel}" }
		
		# main loops
		# read from socket, write to stdout, and handle incoming messages
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
					puts $!.backtrace
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
	
	include Commands
end

# Currently, you have to start one ruby process per connected server. I'm not sure if
# I will change this behavior yet.
this = RBot.new("irc.rizon.net", 6667, "mosfet`rb", "Ruby-Passivated Junction", ["#moshee"])
this.connect

# at_exit { File::open('tell.txt', 'w') { |f| f.write $tell.to_json } }