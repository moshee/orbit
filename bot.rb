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



puts "Connecting!"
# Add triggers above here

this.connect

# at_exit { File::open('tell.txt', 'w') { |f| f.write $tell.to_json } }