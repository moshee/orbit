# encoding: UTF-8
# file: commander.rb
#
# This file contains the Commander class which holds all of the commands. It
# should not be run by itself. The class is used in the RBot class.
#
# All methods defined here are sent exactly one string, whether it be empty or
# not, so they need a space to accept them (or else we get an argument error).
#
# Later, I will probably try a mechanism to use blocks to define triggers, like
# 	cmd_bind('help') { |args| ... }
# This way, I can choose to send args to the block in cmd_bind based on whether
# or not it exists. It will also remove collision with Kernel and Object
# methods.

class Commander
	include IRC
	
	def initialize bot
		@bot = bot
	end
		
	def help args
		if args.empty?
			say "Triggers: \x02calc\x02 (c), \x02imgur\x02 (ir, i), \x02weather\x02 (w), \x02translate\x02 (tl, t), \x02stocks\x02 (s), \x02define\x02 (d), \x02thesaurus\x02 (synonyms, th), \x02tell\x02"
		else
			# do stuff with args
		end
	end
	
	def reload *args
		# close and reopen script (*nix only)
		admin? do
			cmd 'QUIT :reloading'
			system "kill -9 #{$$}; screen -U #{$filename}"
		end
	end
	
	def die *args
		admin? do
			cmd 'QUIT :okay ;_;'
			system "kill -9 #{$$}"
		end
	end
	
	def rt *args
		# reload triggers.rb only (this file)
		admin? { load __FILE__ }
	end
	
	def raw command
		admin? { cmd command }
	end
	
	def please expression
		admin? { eval expression }
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
	
	def imgur *urls
		urls.each do |url|
			if url.match(/^https?:\/\/.+\..+/)
				response = Net::HTTP.post_form(URI.parse("http://api.imgur.com/2/upload.json"), {
					"key"	=>	$api_keys[:imgur],
					"image"	=>	url,
					"type"	=>	"url"
				})
				json = JSON.parse(response.body)
				say url + " => " + json['upload']['links']['original']
			else
				onoez! "Bad URL: '#{url}'"
			end
		end
	end
	alias_method :ir, :imgur
	alias_method :i, :imgur
	
	def weather args
		if args[-3..-1].match(/n:([0-3])/)
			fc_days = $1.to_i
			location = args[0..-4]
		else
			fc_days = 0
			location = args
		end
		weather = (LibXML::XML::Parser.string Net::HTTP.get URI.parse "http://www.google.com/ig/api?weather=#{CGI.escape location}").parse
		condition, temp_f, temp_c, humidity = weather.find('//current_conditions/*').map {|x| x.attributes['data']}[0,4]
		say "Weather in \x02#{weather.find('//city')[0]['data']}\x02: #{temp_f}\xb0F (#{temp_c}\xb0C); #{condition}; #{humidity}"
		if fc_days > 0
			weather.find('//forecast_conditions').map { |w| 
				w.children.map { |x| x }
			}[0,fc_days].each { |y|
				day_of_week, low, high, icon, condition = y.map { |z| z['data'] }[0,5]
				say "\n\x02#{day_of_week}\x02: #{low}-#{high}\xb0F; #{condition}"
			}
		end
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
		end
	end
	alias_method :tl, :translate
	alias_method :t, :translate
	
	def stocks *symbols
		symbols.each do |symbol|
			response = (LibXML::XML::Parser.string Net::HTTP.get URI.parse "http://www.google.com/ig/api?stock=#{symbol}").parse
			derp = response.find('//finance/*').map { |x| x if %w[company exchange currency last high low volume change perc_change].include? x.name }
			derp.delete nil
			company, exchange, currency, last, high, low, volume, change, perc_change = derp.map { |x| x['data'] }
			unless company.empty?
				say "Stock information for \x02#{company}\x02 (#{exchange}, #{currency}): \x02Last\x02 #{last}; \x02High\x02 #{high}; \x02Low\x02 #{low}; \x02Volume\x02 #{volume}; \x02Change\x02 #{change} (#{perc_change}%)"
			else
				onoez! "\"#{symbol}\" is probably an invalid symbol"
			end
		end
	end
	alias_method :s, :stocks
	
	def define query
		response = (LibXML::XML::Parser.string Net::HTTP.post_form(URI.parse 'http://api-pub.dictionary.com/v001', {
				'vid'	=>	$api_keys[:dictionary],
				'q'		=>	query,
				'type'	=>	'define',
				'site'	=>	'dictionary'
			})).parse
		display_form, definitions = response.find('//display_form')[0].content, response.find('//partofspeech')
		n = definitions.length <= 3 ? definitions.length : 3
		definitions.map { |entry| }
		a.each { |x| print "[#{x['pos']}]"; x.find('//def').each {|y| print "#{y}"} }
	end
	alias_method :d, :define
	
	def thesaurus query
	#	syns = entries.gsub(/<a.+?>(\w+)<\/a>/, "\\1").split(", ")
	end
	alias_method :synonyms, :thesaurus
	alias_method :th, :thesaurus
	
	def tell args
		
	end
	
	def encode args
	end
	alias_method :ec, :encode
	
	def decode args
	end
	alias_method :dc, :decode
end