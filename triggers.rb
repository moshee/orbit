# encoding: UTF-8
# file: triggers.rb
#
# This file contains the Triggers module which holds all of the triggers.
# It is included in the RBot class, so all of RBot's instance variables
# are available for use (@source, @)

module Triggers
	def help *args
		if args
			# do stuff
		else
			say "Triggers: \x02calc\x02 (c), \x02imgur\x02 (ir, i), \x02weather\x02 (w), \x02translate\x02 (tl, t), \x02stocks\x02 (s), \x02define\x02 (d), \x02tell\x02"
		end
	end
	
	def reload
		# close and reopen script (*nix only)
		system "kill -9 #{$$}; ruby -w #{@filename}" if permission
	end
	
	def rt
		# reload triggers.rb only (this file)
		load __FILE__ if permission
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
		if args[-4..-1].match(/fc:([0-3])/)
			fc_days = $1.to_i
			location = args[0..-5]
		else
			fc_days = 0
			location = args
		end
		weather = (LibXML::XML::Parser.string Net::HTTP.get URI.parse "http://www.google.com/ig/api?weather=#{CGI.escape location}").parse
		condition, temp_f, temp_c, humidity = weather.find('//current_conditions/*').map {|x| x.attributes['data']}[0,4]
		reply = "Weather in \x02#{weather.find('//city')[0]['data']}\x02: #{temp_f}\xb0F (#{temp_c}\xb0C); #{condition}; #{humidity}"
		if fc_days > 0
			weather.find('//forecast_conditions').map { |w| 
				w.children.map { |x| x }
			}[0,fc_days].each { |y|
				day_of_week, low, high, icon, condition = y.map { |z| z['data'] }[0,5]
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
	
	def stocks symbol
		r = (LibXML::XML::Parser.string Net::HTTP.get URI.parse "http://www.google.com/ig/api?stock=#{symbol}").parse
		derp = r.find('//finance/*').map { |x| x if %w{company exchange currency last high low volume change perc_change}.include? x.name }
		derp.delete nil
		company, exchange, currency, last, high, low, volume, change, perc_change = derp.map { |x| x['data'] }
		unless company.empty?
			say "Stock information for \x02#{company}\x02 (#{exchange}, #{currency}): \x02Last\x02 #{last}; \x02High\x02 #{high}; \x02Low\x02 #{low}; \x02Volume\x02 #{volume}; \x02Change\x02 #{change} (#{perc_change}%)"
		else
			onoez! "\"#{symbol}\" is probably an invalid symbol"
		end
	end
	alias_method :s, :stocks
	
	def define
	end
	alias_method :d, :define
	
	def tell
		
	end
end