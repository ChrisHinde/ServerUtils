#!/usr/bin/env ruby

# Script for generating a secure and user friendly password (part of ServerUtils [su])

# Code from http://ruby.elevatedintel.com/blog/generating-secure-passwords-with-ruby-atmospheric-noise-and-comics/  
# Modified to allow n number of words etc
#   by Christopher Hindefjord - chris@hindefjord.se - http://chris@hindefjord.se - 2014
# Licensed under the MIT License (see LICENSE file)

 
require 'net/http'
require 'nokogiri'
require 'rss'
require 'open-uri'
 
wordlist = Array.new
number_of_words = 4

if ARGV.length >= 1
  number_of_words = ARGV[0].to_i
end

## We try to avoid this method!
##  1. It adds to the overhead
##  2. It produced single words like "HomeUSPoliticsWorldBusinessTechHealthScienceEntertainmentNewsfeedLivingOpinionSportsMagazine" 
#google_news_query = 'http://news.google.com/news/feeds?q=bible&output=rss'
#google_news_result_url = ''
 
#open(google_news_query) do |rss|
#  feed = RSS::Parser.parse(rss)
#  item = feed.items[rand(0..6)]
#    google_news_result_url = item.link
#end

r = rand(15)
num = r > 10 ? r.to_s : '0' + r.to_s
url = 'http://www.manythings.org/vocabulary/lists/l/words.php?f=noll' + num

doc = Nokogiri::HTML(open(url))
 
all_words = ""
doc.traverse{ |node|
  if node.text? and not node.text =~/^\s*$/
    # Avoid URLs
    unless node.text.start_with?('www') 
      all_words << node.text.strip + " "
    end
  end
}

wordlist = all_words.split("\s")
wordlist.each { |word| word.gsub! /\W/, ""; word.strip! }
wordlist.reject!(&:empty?)

random_output = ""
random_data = open("http://www.random.org/integers/?num=#{number_of_words}&min=0&max=#{wordlist.length}&col=1&base=10&format=plain&rnd=new") { |data|
  generated_number = data.read
  random_output << generated_number.strip
}
random_numbers = random_output.split(/\s/).map(&:to_i)

password = ''
for i in 0..(number_of_words-1)
  password << wordlist[random_numbers[i]] + ' '
end

puts password


