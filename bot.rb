# encoding: UTF-8

%w{json net/http socket hpricot cgi htmlentities}.each { |r| require r }

$prefixes = ["]", "."]
$api_keys = {
	:imgur		=>	"",
	:dictionary	=>	""
}
$byte_killer = Iconv.new('UTF-8//IGNORE', 'UTF-8')

module Triggers
	def help *args
		say "Triggers: \x02calc\x02 (c), \x02imgur\x02 (ir, i), \x02weather\x02 (w), \x02translate\x02 (tl, t), \x02stocks\x02 (s), \x02define\x02 (d), \x02tell\x02"
	end
	
	def reload
		`killall -9 ruby; ruby -w bot.rb` if permissions
	end
	
	def calc args
		response = JSON.parse(Net::HTTP.get(URI.parse("http://www.google.com/ig/calculator?hl=en&q=#{CGI.escape(args)}")).gsub(/([^,{]+):/,"\"\\1\":"))
		if ['', '0'].include? response['error']
			rhs = ($byte_killer.iconv response['rhs']).gsub(/ x26#215;\s10x3csupx3e(\-?\d+)x3c\/supx3e/,"e\\1").gsub(/x3csupx3e(\-?\d+)x3c\/supx3e/,"\^\\1")
			say "#{response['lhs']} = #{rhs}"
		else
			onoez! response['error']
		end
	end
	alias_method :c, :calc
	
	def imgur urls
		urls.split(' ').each do |url|
			if url.match(/^https?:\/\//)
				response = Net::HTTP.post_form(URI.parse "http://api.imgur.com/2/upload.json", {
					"key"	=>	$api_keys[:imgur],
					"image"	=>	url,
					"type"	=>	"url"
				})
				json = JSON.parse(response.body)
				say url + " => " + json['upload']['links']['original']
			else
				say "Bad URL: '#{url}'"
			end
		end
	end
	alias_method :ir, :imgur
	alias_method :i, :imgur
	
	def weather args
		if args[-4..-1].match(/fc:([0-3])/)
			fc_days = $1.to_i
			location = args[0..-5]
		else
			fc_days = 0
			location = args
		end
		weather = Hpricot::XML Net::HTTP.get URI.parse("http://www.google.com/ig/api?weather=#{CGI.escape(location, /\W/)}")
		condition, temp_f, temp_c, humidity = (weather/:current_conditions/:*).map {|x| x.attributes['data']}[1,4]
		reply = "Weather in \x02#{weather.at('city').attributes['data']}\x02: #{temp_f}\xb0F (#{temp_c}\xb0C); #{condition}; #{humidity}"
		if fc_days > 0
			weather.search("forecast_conditions").map { |w| 
				(w/:*).map { |x| x } 
			}[0,fc_days].each { |y|
				day_of_week, low, high, icon, condition = y.map { |z| z.attributes['data'] }[1,5]
				reply << "\n\x02#{day_of_week}\x02: #{low}-#{high}\xb0F; #{condition}"
			}
		end
		say reply
	end
	alias_method :w, :weather
	
	def translate args
		lang_pair, lol, query = args.partition ' '
		if lang_pair.match(/([a-z]{2})?\|[a-z]{2}/)
			response = JSON.parse Net::HTTP.get URI.parse URI.escape "http://ajax.googleapis.com/ajax/services/language/translate?v=1.0&q=#{query}&langpair=#{lang_pair}"
			if response['responseStatus'] == 200
				reply = response['responseData']['translatedText']
				if d_source_lang = response['responseData']['detectedSourceLanguage']
					reply = "[\x02#{d_source_lang}\x02] #{reply}"
				end
				say reply
			else
				onoez! "HTTP Error: #{response['responseStatus']}"
			end
		else
			onoez! "Invalid language pair"
			return false
		end
	end
	alias_method :tl, :translate
	alias_method :t, :translate
	
	def stocks args
		r = Hpricot::XML Net::HTTP.get URI.parse "http://www.google.com/ig/api?stock=#{args}"
		unless r.at(:company)['data'].empty?
			say "Stock information for \x02#{r.at(:company)['data']}\x02 (#{r.at(:exchange)['data']}, #{r.at(:currency)['data']}): \x02Last\x02 #{r.at(:last)['data']}; \x02High\x02 #{r.at(:high)['data']}; \x02Low\x02 #{r.at(:low)['data']}; \x02Volume\x02 #{r.at(:volume)['data']}; \x02Change\x02 #{r.at(:change)['data']} (#{r.at(:perc_change)['data']}%)"
		else
			onoez! "\"#{args}\" is probably an invalid symbol"
		end
	end
	alias_method :s, :stocks
	
	def define
	end
	alias_method :d, :define
	
	def tell
	end
end

class RBot
	@@copy = 0
	def initialize server, port=6667, nick, user, channels
		@socket = TCPSocket.new(server,port)
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
	
	def onoez! reason=''
		reply = "#{@nick}: I am error"
		reply << " (#{reason})" unless reason.empty?
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
			puts "*** [ThingDoer.handle] NoMethodError: #{$!}"
		rescue ArgumentError
			say "Argument Error: #{$!}"
		end
	end
	
	def privmsg
		if ['#','&'].include? @target[0] and $prefixes.include? @message.slice! 0	# public message
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
		return true if @source.match(/moshee@mo\.sh\.ee|24.16.155.210/)
	end
	
	def connect
		# login
		cmd "USER RBOT-#{@current_copy} 0 0 :#{@user}"
		cmd "NICK #{@nick}"
		@channels.each { |channel| cmd "JOIN #{channel}" }
		
		# main loops
		# read from socket
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
					puts "*** #{$!}"
					retry
				end
			end
		end
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