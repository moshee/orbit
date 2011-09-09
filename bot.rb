#!/usr/bin/env ruby -w
# encoding: UTF-8
# file: bot.rb

print "Loading dependencies... "
%w[json net/http libxml cgi htmlentities optparse yaml].each do |r|
  print r + '... '
  require r
end
puts

OptionParser.new do |args|
  args.on('-p', '--profile [NUMBER]', 'Use config profile NUMBER (in config.yml)') { |profile| PROFILE = profile}
end.parse!

if not defined? PROFILE then raise RuntimeError, "\033[31;1mServer profile not given.\033[0m" end

puts "Loading main source files..."
load 'orbit.rb'

puts "Startup procedures..."
# makes the google dictionary api work properly
byte_killer = Iconv.new 'UTF-8//IGNORE', 'UTF-8'

# for decoding HTML entities
html_decoder = HTMLEntities.new('expanded')

# for the tell command
begin
  File::open('tell.txt') { |f| $tell = JSON.parse f.read }
rescue Errno::ENOENT
  File.new('tell.txt', 'w') { |f| f.write '{}'}
  retry
rescue JSON::ParserError
end

puts "Instantiating bot..."
# Currently, you have to start one ruby process per connected server. I'm not 
# sure if I will change this behavior yet.
this = Orbit::Bot.new PROFILE


puts "Binding triggers..."
# Add triggers below here

this.bind 'reload' do
  # close and reopen script (*nix only)
  admin? do
    cmd 'QUIT :reloading'
    exit!
    system "screen -U ./#{__FILE__} -p #{$profile}"
  end
end


this.bind 'help' do |args|
  if args.nil?
    say "Triggers: \x02calc\x02 (c), \x02imgur\x02 (ir, i), \x02weather\x02 (w), \x02translate\x02 (tl, t), \x02stocks\x02 (s)"
  else
    # do stuff with args
  end
end


this.bind 'die' do
  admin? do
    cmd 'QUIT :okay ;_;'
    exit!
  end
end


this.bind 'raw' do |command|
  admin? { cmd command }
end


this.bind 'please' do |expression|
  admin? { eval expression }
end


this.bind 'calc', 'c' do |args|
  response = JSON.parse(Net::HTTP.get(URI.parse("http://www.google.com/ig/calculator?hl=en&q=#{CGI.escape(args)}")).gsub(/([^,{]+):/,"\"\\1\":"))
  if ['', '0'].include? response['error']
    rhs = (byte_killer.iconv response['rhs']).gsub(/ x26#215;\s10x3csupx3e(\-?\d+)x3c\/supx3e/,"e\\1").gsub(/x3csupx3e(\-?\d+)x3c\/supx3e/,"\^\\1")
    say "#{response['lhs']} = #{rhs}"
  else
    onoez! response['error']
  end
end


this.bind 'imgur', 'im' do |urls|
  urls.split(' ').each do |url|
    if url.match(/^https?:\/\/.+\..+/)
      response = Net::HTTP.post_form(URI.parse("http://api.imgur.com/2/upload.json"), {
        "key" =>  '86479b06ff689612409190829dd46576',
        "image" =>  url,
        "type"  =>  "url"
      })
      
      json = JSON.parse(response.body)
      
      say url + " => " + json['upload']['links']['original']
    else
      onoez! "Bad URL: '#{url}'"
    end
  end
end


this.bind 'weather', 'w' do |args|
  
  if args[-3..-1].match(/n=([0-3])/)
    n = $1.to_i
    location = args[0..-4]
  else
    n = 0
    location = args
  end
  
  weather = (LibXML::XML::Parser.string Net::HTTP.get URI.parse "http://www.google.com/ig/api?weather=#{CGI.escape location}").parse
  weather.encoding = LibXML::XML::Encoding::UTF_8
  
  condition, temp_f, temp_c, humidity = weather.find('//current_conditions/*').map { |x| x.attributes['data'] }[0,4]
  
  say "Weather in \x02#{weather.find('//city')[0]['data']}\x02: #{temp_f}\xb0F (#{temp_c}\xb0C); #{condition}; #{humidity}"
  
  if (1..3).include? n
    weather.find('//forecast_conditions').map { |w| w.children.map { |x| x } }[0,n].each do |y|
      day_of_week, low, high, icon, condition = y.map { |z| z['data'] }[0,5]
      say "\x02#{day_of_week}\x02: #{low}-#{high}\xb0F; #{condition}"
    end
  end
end

this.bind 'translate', 'tl', 't' do |query|
  lang_pair = query.slice!(/([a-z]{2})?(\||\s?)[a-z]{2}/)
  query.lstrip!
  
  if lang_pair
    response = JSON.parse Net::HTTP.get URI.parse URI.escape "http://ajax.googleapis.com/ajax/services/language/translate?v=1.0&q=#{query}&langpair=#{lang_pair}"
    
    if response['responseStatus'] == 200
      reply = html_decoder.decode response['responseData']['translatedText']
      
      if d_source_lang = response['responseData']['detectedSourceLanguage']
        say "[\x02#{d_source_lang}\x02] #{reply}"
      else
        say reply
      end
      
    else
      onoez! "HTTP Error: #{response['responseStatus']}"
    end
    
  else
    onoez! "Invalid language pair"
  end
end


this.bind 'stocks', 's' do |symbols|
  symbols.split(' ').each do |symbol|
    response = (LibXML::XML::Parser.string Net::HTTP.get URI.parse "http://www.google.com/ig/api?stock=#{symbol}").parse
    
    derp = response.find('//finance/*').map do |x|
			x if %w(company exchange currency last high low volume change perc_change).include? x.name
    end
    derp.delete nil
    
    company, exchange, currency, last, high, low, volume, change, perc_change = derp.map { |x| x['data'] }
    
    unless company.empty?
      say "Stock information for \x02#{company}\x02 (#{exchange}, #{currency}): \x02Last\x02 #{last}; \x02High\x02 #{high}; \x02Low\x02 #{low}; \x02Volume\x02 #{volume}; \x02Change\x02 #{change} (#{perc_change}%)"
      
    else
      onoez! "\"#{symbol}\" is probably an invalid symbol"
    end
  end
end


this.bind 'define', 'def' do |query|
  
end


this.bind 'thesaurus', 'synonyms', 'th' do |query|
  n = 10
  
  if query[-3..-1].match(/n=([0-3][0-9]?)/) and (n = $1.to_i) != 0
    query = query[0..-4]
  end
  
  response = (LibXML::XML::Parser.string Net::HTTP.get URI.parse "http://api-pub.dictionary.com/v001?vid=ukgjitziiotr3nb3xwo99uzv0iovuc3pwk8fe8yxwr&q=#{query}&type=define&site=thesaurus").parse
  
  if items = response.find('//synonyms/item').empty?
    syns = response.find('//synonyms').map { |entry| entry.content.gsub(/<a.+?>(\w+)<\/a>/, "\\1").split(', ') }.flatten
  else
    syns = items.map { |item| item.content }
  end
  
# n.times
end

this.bind 'tell' do |args|
  
end


this.bind 'encode', 'ec' do |input|
  
end


this.bind 'decode', 'dc' do |input|
  
end

this.bind 'google', 'g' do |query|
  response = (JSON.parse Net::HTTP.get URI.parse "https://www.googleapis.com/customsearch/v1?key=AIzaSyChF5xTtpvEYGUxhOSa6f7Bsa9SEWUvdR4&cx=013036536707430787589:_pqjad5hr1a&q=#{CGI.escape query}")['items'][0]
  
  if response then say "#{response['title']} \x02[\x02#{response['link']}\x02]\x02" end
end


this.bind 'googl', 'shorten' do |long_url|
  response = JSON.parse Net::HTTP.new.request_post(  'https://www.googleapis.com/urlshortener/v1/url', %[{"longURL": "#{long_url}"}], {'Content-type' => 'application/json'} ).body
end


puts "Connecting!"
# Add triggers above here

this.connect

# at_exit { File::open('tell.txt', 'w') { |f| f.write $tell.to_json } }