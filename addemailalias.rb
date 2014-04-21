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
  puts "USAGE:"
  puts "\t" + __FILE__ + " ALIAS MOTTAGARE [ARGUMENT]"
  print "\n"
  puts "Exempel:"
  puts "\t" + __FILE__ + " arthur@example.com arthur.dent@example.com"
  puts "\t" + __FILE__ + " zaphod@example.net zaphod@example.com"
  puts "\nArgument:"
  puts "\t-h, --help\t\t\tVisa denna information"
  puts "\t-s, --simulate\t\t\tSimulera allt, gör inga ändringar i filsystem eller databas"
  print "\n"

  # We also exit the script here..
  exit(0)
end

# Does all the initial processing
def init
  # Validate and parse the flags
  OptionParser.new do |o|
    o.on('-s',            '--simulate')             { |b| $simulate = b }
    o.on('-h',            '--help')                 { usage }
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
    puts "Mottagaradressen (#{$email}) ser inte ut som en e-postadress!".red
    exit
  end
end

# The main method, it just calls other methods
def main
  # Say hello to the user
  puts "Skapar ett alias för '#{$alias}' till '#{$email}'"
  puts "-----------------------\n"

  puts "Kör i simuleringsläge!".pink if $simulate

  # Add the alias	
  add_to_database
end

# Method that adds the alias to the database
def add_to_database
  # Tell the user what's going on
  puts "> Ansluter till databasen".green
  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  # Tell the user what's going on
  puts "> Lägger till aliaset i databasen".green
  # Insert the account into the correct table
  conn.exec_params "INSERT INTO #{DB_ALIAS_TABLE} (address, userid)" +
                      " VALUES ($1, $2)",
                    [$alias, $email] unless $simulate

  # Tell the user what's going on
  puts "> Kopplar från databasen".green
  # Close the connection
  conn.close
end

###############################################################################
# Main "program code"

# Initiate the script (check arguments etc) 
init

# Run the main "program"
main
