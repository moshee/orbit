# encoding: UTF-8
# file: orbit.rb

=begin
This file contains the main RBot module which contains classes to connect to a 
server, send and receive text, and handle responses. RBot::Bot is a hash of 
Procs. Each Proc is executed when its key is matched in IRC. Commands are added
(bound) between instantiation of RBot::bot in the main run script and
RBot::Bot#connect.

Usage:

bot = RBot.new([...])

bot.bind('test', 't') do |msg, nick, host, channel|
  say "#{nick}: you said \"#{msg}\""
end

(...)

bot.connect
=end

require 'socket'

load 'events.rb'


module Orbit
	CFG = YAML.load_file 'config.yml'
	
	class Bot < Hash
		def initialize profile
      if CFG['profiles'][profile].nil? then raise RuntimeError, "\033[31;1mProfile `#{profile}' does not exist.\033[0m" end
			
			@server   = CFG['profiles'][profile]['server']
			@port     = CFG['profiles'][profile]['port']     || 6667
			@botnick  = CFG['profiles'][profile]['nick']     || "orbit"
			@botuser  = CFG['profiles'][profile]['user']     || "orbit"
			@botname  = CFG['profiles'][profile]['realname'] || "Orbit - Ruby IRC bot"
			@channels = CFG['profiles'][profile]['join']     || []
			
			if @server.nil? then raise RuntimeError, "\033[31;1mServer not provided. Please check your config.yml\033[0m" end
			
			@admins = /#{CFG['admins']}/
			
			reset_everything
		end
		
		def reset_everything
      @joined_channels = {}
      @joined_on_startup = false
		end
		
		def try_for_reconnect
      sleep 60
      reset_everything
      puts
      puts "\033[35;1mAttempting to reconnect...\033[0m"
      connect
		end
		
		def bind *triggers, &block
			triggers.each { |trigger| store trigger, block }
		end
		
		def perform trigger, *args
			instance_exec(*args, &self[trigger])
		end
		
		def connect
      @sock = TCPSocket.new @server, @port
      
			# login
			cmd "USER #{@botuser} 0 0 :#{@botname}"
			cmd "NICK #{@botnick}"
			
			# main loops
			# read from socket, write to stdout, and handle incoming messages
			read_thread = Thread.new do
				while true
					begin     
						ready = IO.select([@sock], nil, nil)
						redo if !ready
						try_for_reconnect if @sock.eof?
						handle @sock.gets.chomp
					rescue Exception
						puts "\033[37;41m[\033[1;37;41mMain Loop\033[37;41m] #{$!}\033[0m", $@
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
		

#		/^(:\S+)?\s?([A-Z0-9]+)\s:?([^,\s]+)\s?:?(.+)?$/
#		/(:\S+)? ?([A-Z]+) (#?[^,\s]* )?:(.+)/
	
		def handle line
			@source = (line.slice!(/^:\S+ /) || '')[1..-2]
			@raw_command = line.slice!(/[A-Z0-9]+ /)[0..-2]
			@params, nope, @message = line.partition ':'
			
#			line.match(/^(:\S+)?\s?([A-Z0-9]+)\s:?([^,\s]+)\s?:?(.+)?$/)
#			@source, @raw_command, @target, @message = $1, $2, $3, $4
#			@source[0] = '' unless @source.nil?
			
			if @message and EVENTS.include? @raw_command
        Thread.new do
          puts '<-- ' << (eval(EVENTS[@raw_command][1] || 'line'))
  #				log "[#{Time.now.strftime '%F %T'}] <#{@source.nick}> #{@message}"
        end.join
				instance_eval(&EVENTS[@raw_command][0])
			else
        puts "<-- [#{@source}] [#{@raw_command}] [#{@params}] [#{@message}]"
			end
		end
		
		def log line
			if logfile = eval(CFG['log'])
				File::open logfile, 'w+' do |file|
					file.write line << "\n"
				end
			end
		end
		
		def cmd str
			@sock.send "#{str}\r\n", 0
			puts "--> #{str}"
		end
		
		def say str, target = @params
			str.to_s.each_line { |line| cmd "PRIVMSG #{target} :#{line.chomp}" }
		end
		
		def action str, target = @params
			say "\1ACTION #{str}\1", target
		end
		
		def ctcp str, target = @params
			say "\1#{str}\1", target
		end
		
		def onoez! problem = ''
			reply = "I am error"
			reply << " (#{problem})" unless problem.empty?
			say reply
		end
		
		def admin?
			if @source.match(@admins)
				yield if block_given?
				return true
			else
				action "slaps #{@source.nick}\'s hand away from the big red button" if block_given?
				return false
			end
		end
	end
	
	class Channel
		def initialize names
			@names = names.split
		end
		
		def joined user
			names.push user
		end
		
		def parted user
			names.delete user
		end
	end
end

class String
	def nick
		self[/[^~!]+/]
	end
	
	def user
		self[/![^@]+@/][1..-2]
	end
	
	def host
		self[/@.+$/][1..-1]
	end
	
	def userhost
		str[/!.+$/]
	end
end
