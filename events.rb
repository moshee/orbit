# encoding: UTF-8

module Orbit
	EVENTS = {
    # public channel message
    'PRIVMSG' => [
      Proc.new do
        if ['#','&'].include?(@params[0]) \
          and @message.sub!(/^#{@botnick}\s*(,|:)\s*/, '') \
          or CFG['prefixes'].include?(@message.slice! 0) \
          
          perform @message.slice!(/\w+/), @message[1..-1]
        end
      end,
      '"[\033[1m->#{@params}\033[0m] <\033[1;34m#{@source.nick}\033[0m> #{@message}"'
    ],
    
    # server ping
    'PING' => [
      Proc.new { cmd "PONG :#{@message}" },
      '"\033[1m#{@raw_command}\033[0m #{@message}"'
    ],
    
    # notice from user
    'NOTICE' => [
      Proc.new {},
      '"[\033[1m->#{@params}\033[0m] -\033[1;31m#{@source.nick}\033[0m- #{@message}"'
    ],
    
    # channel join
    'JOIN' => [
      Proc.new do
#        if @source.nick == @botnick
#					@joined_channels.store @params, Orbit::Channel.new
#        else
#          @joined_channels[@target].users.push @source
#        end
      end,
      '"\033[1m#{@source.nick}\033[0m joined \033[1m#{@params || @message}\033[0m"'
    ],
    
    # channel part
    'PART' => [
      Proc.new do
#        if @source.nick != @botnick
#          @joined_channels[@target].users.delete @source
#        end
      end,
      '"\033[1m#{@source.nick}\033[0m left \033[1m#{@params || @message}\033[0m"'
    ],
    
    # nick change
    'NICK' => [
      Proc.new do
#        @joined_channels.each do |channel|
#          channel.users[channel.users.index @source.nick].gsub!(/^#{@source.nick}/, @message)
#        end
      end,
      '"\033[1m#{@source.nick}\033[0m is now known as \033[1m#{@params}\033[0m"'
    ],
    
    # quit
    'QUIT' => [
      Proc.new do
#        @joined_channels.each { |channel| channel.users.delete @source }
      end,
      '"\033[1m#{@source.nick}\033[0m quit (#{@message})"'
    ],
    
    'MODE' => [
			Proc.new {}
		],
    
    # /WHO list
    '352' => [
      Proc.new do
        
      end
    ],
    
    # /NAMES list
    '353' => [
      Proc.new {}
    ],
    
    # MOTD message
    '372' => [
      Proc.new {},
    ],
    
    # end of MOTD
    '376' => [
      Proc.new {
        unless @joined_on_startup
          @channels.each { |channel| cmd "JOIN #{channel}" }
          cmd "PRIVMSG NickServ :identify #{@nickpass}" if @nickpass
          @joined_on_startup = true
        end
      }
    ],
    
    # Nick already in use
    '433' => [
      Proc.new do
#        if (index = @altnicks.index @nick) >= @altnicks.length
#          cmd "NICK #{@nick = @altnicks[index + 1]}"
#        else
          cmd "NICK #{@nick << '_'}"
#        end
      end
    ]
  }
end