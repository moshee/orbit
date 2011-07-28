# encoding: UTF-8
# file: triggers.rb
#
# This file contains the Triggers module which holds all of the triggers.
# It is included in the RBot class, so all of RBot's instance variables
# are available for use (@source, @)

module Triggers
	def help *args
		say "Triggers: \x02calc\x02 (c), \x02imgur\x02 (ir, i), \x02weather\x02 (w), \x02translate\x02 (tl, t), \x02stocks\x02 (s), \x02define\x02 (d), \x02tell\x02"
	end
	
	def reload
		system "kill -9 #{$$}; ruby -w #{@filename}" if permissions
	end
	
	def rt
		# reload triggers.rb only (this file)
		load __FILE__ if permissions
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