# encoding: UTF-8
# file: rbot.rb

=begin
This file contains the main RBot class which connects to a server, sends and
receives text, and handles responses. RBot is a hash of Procs. Each Proc is 
executed when its key is matched in IRC. Commands are added (bound) between
instantiation of RBot in the main run script and RBot#connect.

Usage:

bot = RBot.new([...])

bot.bind('test', 't') do |nick, host, msg|
	say "#{nick}: you said \"#{msg}\""
end

bot.connect
=end

class RBot < Hash
	@@copy = 0
	
	def initialize server, port=6667, nick, user, channels
		@sock = TCPSocket.new(server,port)
		@filename = __FILE__
		
		# these instance variables are accessible from all triggers in Triggers
		@botnick, @channels, @current_copy, @user = nick, channels, (@@copy += 1), user
		
		@handle_events = {
			'PRIVMSG' => Proc.new do
				# public channel message (lol irc protocol)
				if ['#','&'].include?(@target[0]) and @message.sub!(/^#{@botnick}\s*(,|:)\s*/, '') or $prefixes.include?(@message.slice! 0)
					perform @message.slice!(/\w+/), @message[1..-1]
					
				end
			end,
			
			'PING' => Proc.new { cmd "PONG :#{@message}" },
		}
	end
	
	def bind *triggers, &block
		triggers.each { |trigger| store trigger, block }
	end
	
	def perform trigger, *args
		instance_exec(*args, &self[trigger])
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
					ready = IO.select([@sock], nil, nil)
					redo if !ready
					exit! if @sock.eof?
					line = @sock.gets
#					puts "<-- #{line.chomp!}"
					handle line.chomp!
				rescue Exception
					puts "*** [\033[1mMain Loop\033[0m] #{$!}", $@
					retry
				end
			end
		end
		# write to socket from stdin
		write_thread = Thread.new do
			while line = gets.chomp
				cmd line
			end
		end
		
		read_thread.join
		write_thread.join
	end
	
	private
	
=begin
Two options for regexes.

/(:\S+\s)?(\S+|\d{3})\s((#|&)?[\w\\\[\]{}\^`\|][\w\-\\\[\]{}\^`\|]*\s)?{1,2}:(.+)/
-	matches all lines including numerical responses (\d{3}) (still in progress)

/(:\S+)? ?([A-Z]+) (#?[\w\-\\\[\]{}\^`\|]* )?:(.+)/
-	matches only regular commands (PRIVMSG, PING, NICK, NOTICE, ...)
=end

	def handle line
		line.match(/(:\S+)? ?([A-Z]+) (#?[\w\-\\\[\]{}\^`\|]* )?:(.+)/)
		@source, @raw_command, @target, @message = $1, $2, $3, $4
		@nick = @source[/[^~!:]+/] unless @source.nil?
		@target.rstrip! unless @target.nil?
		
		if @target
			puts "<-- [\033[1m#{@raw_command} -> #{@target}\033[0m] <\033[1;34m#{@nick}\033[0m> #{@message}"
		else
			puts "<-- #{line}"
		end
		
		instance_eval(&@handle_events[@raw_command]) if @raw_command and @message and @handle_events.include? @raw_command
		
	rescue ArgumentError
		puts $!, $@
	end
	
	# IRC methods
	
	def cmd str
		puts "--> #{str}"
		@sock.send "#{str}\r\n", 0
	end
	
	def say str, target = @target
		str.to_s.each_line { |line| cmd "PRIVMSG #{target} :#{line.chomp}" }
	end
	
	def action str, target = @target
		say "\1ACTION #{str}\1", target
	end
	
	def ctcp str, target = @target
		say "\1#{str}\1", target
	end
	
	def onoez! problem = ''
		reply = "I am error"
		reply << " (#{problem})" unless problem.empty?
		say reply
	end
	
	def admin?
		if @source.match($admin_hostmasks)
			yield if block_given?
			return true
		else
			action "slaps #{@nick}\'s hand away from the big red button" if block_given?
			return false
		end
	end
end