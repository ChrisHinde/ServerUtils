#!/usr/bin/env ruby
# encoding: utf-8

# Script for generating a secure and user friendly password (part of ServerUtils [su])

# Code originally based on http://ruby.elevatedintel.com/blog/generating-secure-passwords-with-ruby-atmospheric-noise-and-comics/  
#   Modified by Christopher Hindefjord - chris@hindefjord.se - http://chris@hindefjord.se - 2014
# Licensed under the MIT License (see LICENSE file)

 
require 'net/http'
require 'optparse'
require 'open-uri'
require_relative 'su_lib.rb'

include ServerUtils_Lib
 
wordlist = Array.new
$number_of_words = 4
$lang = 'se'


# Method for printing the "usage information"
def usage
  puts <<EOU
Användning:
  #{__FILE__} [LÄNGD] [ARGUMENT]

Generera lösenord

Exempel:
  #{__FILE__} 5
  #{__FILE__} 7 -l se

Argument:
  -h, --help               Visa denna information

  -l, --lang LANG          Använd språket LANG för lösenordet (en = Engelska, se = Svenska)

  LÄNGD                    Antal ord i lösenorder

Genererar ett lösenord bestående av LÄNGD antal slumpade ord (Standardlängden är 4 ord).
Kan generera lösenord på både svenska och engelska.

Ett antal slumpade ord hämtas först från en extern ordlista, av dem slumpas sedan LÄNGD antal ord för att bilda lösenordet.

OBS! Mellanslagen är en del av lösenordet!
EOU

  # We also exit the script here..
  exit(0)
end

# Validate and parse the flags
OptionParser.new do |o|
  o.on('-l LANG',     '--lang LANG')        { |l| $lang = l }
  o.on('-h',          '--help')             { usage }
  o.parse!
end

if ARGV.length >= 1
  $number_of_words = ARGV[0].to_i
end

url = 'http://hus42.se/word_rack/' + $lang + "/" + ($number_of_words * 5).to_s

all_words = open(url).read

wordlist = all_words.split("\n")

random_numbers = []
for i in 1..$number_of_words
  random_numbers.push rand(wordlist.length)
end

password = ''
for i in 0..($number_of_words-1)
  password << wordlist[random_numbers[i]] << ' '
end

puts password


