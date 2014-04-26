#!/usr/bin/env ruby
# encoding: utf-8

# Script for creating a new e-mail account (part of ServerUtils [su])
# Created by Christopher Hindefjord - chris@hindefjord.se - http://chris@hindefjord.se - 2014
# Licensed under the MIT License (see LICENSE file)

require 'optparse'
require 'io/console'
require 'fileutils'
require 'pg'
#require 'digest'

require_relative 'su_config.rb'
require_relative 'su_lib.rb'

include ServerUtils_Lib

$simulate = false
$alias = ''
$email = ''

# Method for printing the "usage information"
def usage
  puts <<EOU
USAGE:
  #{__FILE__} ALIAS E-POST [ARGUMENT]

Ta bort ett e-postalias från mailservern

Exempel:
  #{__FILE__} arthur@example.com arthur.dent@example.com
  #{__FILE__} zaphod@example.net zaphod@example.com

Argument:
  -h, --help        Visa denna information
  -s, --simulate    Simulera allt, gör inga ändringar i filsystem eller databas

För att ta bort ett alias måste "hela" aliaset anges (Dvs både ALIAS och MOTTAGARE).
I nuvarande version går det inte att ta bort alla mottagare för ett alias på en gång!
EOU

  # We also exit the script here..
  exit(0)
end

# Does all the initial processing
def init
  # Validate and parse the flags
  OptionParser.new do |o|
    o.on('-s',          '--simulate')         { |b| $simulate = b }
    o.on('-h',          '--help')             { usage }
    o.parse!
  end

  # If we didn't get enough arguments, output usage
  usage if ARGV.length < 2

  # Get the arguments
  $alias = ARGV[0]
  $email = ARGV[1]

  if $alias.match(EMAIL_REGEX).nil?
    puts "Aliasadressen (#{$alias}) ser inte ut som en e-postadress!".red
    exit
  elsif $email.match(EMAIL_REGEX).nil?
    puts "E-postadressen (#{$email}) ser inte ut som en e-postadress!".red
    exit
  end
end

# The main method, it just calls other methods
def main
  # Say hello to the user
  puts "Ta bort aliaset för '#{$alias}' '#{$email}'".green
  puts "-----------------------\n".green

  puts "Kör i simuleringsläge!".pink if $simulate

  # Delete the alias
  delete_db_post
end

# Method that removes the alias from the db
def delete_db_post
  # Tell the user
  puts "> Tar bort aliaset från databasen".green

  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  # Delete the account
  res = conn.exec "DELETE FROM #{DB_ALIAS_TABLE} WHERE address = '#{$alias}' AND userid = '#{$email}'" unless $simulate

  # Close the connection
  conn.close
end

###############################################################################
# Main "program code"

# Initiate the script (check arguments etc) 
init

# Run the main "program"
main
