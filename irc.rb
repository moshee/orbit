# encoding: UTF-8
# file: irc.rb
#
# The IRC module contains methods used to send messages to the IRC server.

module IRC
	private
	def ping
		cmd "PONG :#{$message}"
	end
	
	def notice
	end
	
	def cmd str
		puts "--> #{str}"
		$sock.send "#{str}\r\n", 0
	end
	
	def say str, target = $target
		str.to_s.each_line { |line| cmd "PRIVMSG #{target} :#{line}" }
	end
	
	def action str, target = $target
		say "\1ACTION #{str}\1", target
	end
	
	def ctcp str, target = $target
		say "\1#{str}\1", target
	end
	
	def onoez! problem = ''
		reply = "I am error"
		reply << " (#{problem})" unless problem.empty?
		say reply
	end
	
	def admin?
		if $source.match($admin_hostmasks)
			yield if block_given?
			return true
		else
			action "slaps #{$nick}\'s hand away from the big red button" if block_given?
			return false
		end
	end
end