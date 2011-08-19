# encoding: UTF-8
# file: rbot.rb

=begin
This file contains the main RBot class which connects to a server, sends and
receives text, and handles responses. The actual work is done by the Commander
class, but RBot 
=end

class RBot
	@@copy = 0
	include IRC
	
	attr_reader :sock, :filename
	
	def initialize server, port=6667, nick, user, channels
		@sock = TCPSocket.new(server,port)
		@filename = __FILE__
		
		# these instance variables are accessible from all triggers in Triggers
		@botnick, @channels, @current_copy, @user = nick, channels, (@@copy += 1), user
		
		@commander = Commander.new self
	end
	
#	Two options for regexes.
#
#	/(:\S+\s)?(\S+|\d{3})\s((#|&)?[\w\\\[\]{}\^`\|][\w\-\\\[\]{}\^`\|]*\s)?{1,2}:(.+)/
#	-	matches all lines including numerical responses (\d{3}) (still in progress)
#	
#	/(:\S+)? ?([A-Z]+) (#?[\w\-\\\[\]{}\^`\|]* )?:(.+)/
#	-	matches only regular commands (PRIVMSG, PING, NICK, NOTICE, ...)

	def handle line
		begin
			line.match(/(:\S+)? ?([A-Z]+) (#?[\w\-\\\[\]{}\^`\|]* )?:(.+)/)
			$source, $raw_command, $target, $message = $1, $2, $3, $4
			$nick = $source[/[^~!:]+/] if not $source.nil?
			self.send $raw_command.downcase! if $raw_command and $message
		rescue NoMethodError
			puts "*** [RBot.handle] NoMethodError: #{$!}"
		rescue ArgumentError
			say "Argument Error: #{$!}"
		end
	end
	
	def privmsg
		# public channel message (lol irc protocol)
		if ['#','&'].include?($target[0]) and $message.sub!(/^#{@botnick}\s*(,|:)\s*/, '') or $prefixes.include?($message.slice! 0)
			command, lol, args = $message.partition ' '
			Thread.new { @commander.public_send command, args }
		end
	end
	
	def ping
		cmd "PONG :#{$message}"
	end
	
	def notice
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
					ready = select([@sock], nil, nil)
					redo if !ready
					exit! if @sock.eof?
					line = @sock.gets
					puts "<-- #{line.chomp!}"
					handle line
				rescue Exception
					puts "*** [Main Loop] #{$!}", $!.backtrace
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
end