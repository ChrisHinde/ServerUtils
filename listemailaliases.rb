#!/usr/bin/env ruby
# encoding: utf-8

# Script for listing existing e-mail accounts (part of ServerUtils [su])
# Created by Christopher Hindefjord - chris@hindefjord.se - http://chris@hindefjord.se - 2014
# Licensed under the MIT License (see LICENSE file)

require 'optparse'
require 'io/console'
require 'fileutils'
require 'pg'

require_relative 'su_config.rb'
require_relative 'su_lib.rb'

include ServerUtils_Lib

# Method for printing the "usage information"
def usage
  puts "USAGE:"
  puts "\t" + __FILE__ + " [ARGUMENT]"
  puts "\nArgument:"
  puts "\t-h, --help\t\t\tVisa denna information"
  print "\n"

  puts "\t-a, --alias ALIAS\t\tLista alias vars 'alias' matchar ALIAS"
  puts "\t-r, --reciever MOTTAGARE\tLista alias vars 'mottagare' matchar MOTTAGARE"

  # We also exit the script here..
  exit(0)
end

# Does all the initial processing
def init
  # Validate and parse the flags
  OptionParser.new do |o|
    o.on('-a ALIAS',    '--alias ALIAS')        { |a| $alias = a }
    o.on('-r RECIEVER', '--reciever RECIEVER')  { |e| $email = e }
    o.on('-h',          '--help')               { usage }
    o.parse!
  end
end

# The main method, it just calls other methods
def main
  # Say hello to the user
  puts "Listar existerande e-postalias".green
  puts "-----------------------\n".green

  # List the accounts
  list_aliases
end

# Method that lists the accounts
def list_aliases
  # Get the accounts from the database
  aliases = get_aliases

  # Figure out the "widest" value in each column
  l = { :address => [5], :userid => [9] }
  aliases.each { |t|
    l[:address] << t['address'].length
    l[:userid] << t['userid'].length
  }

  f_str = "| %-" + l[:address].max.to_s + "s | %-" + l[:userid].max.to_s + "s |"

  # Output the table with users
  puts f_str % [ 'Alias', 'Mottagare' ] # Heading
  l.each { |k,v|
    print "|-"
    v.max.times { print "-" }
    print "-"
  }
  puts "|"

  # Output the rows with data
  aliases.each { |t|
    puts f_str % [ t['address'], t['userid'] ]
  }

  print "\n"
end


# Method that retrieves the aliases
def get_aliases
  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  w = ''

  if $alias || $email
    w = " WHERE"
    w << " address LIKE '#{$alias}'" if $alias
    w << " AND" if $alias && $email
    w << " userid LIKE '#{$email}'" if $email
  end
p w
  # Insert the user into the correct table
  res = conn.exec "SELECT * FROM #{DB_ALIAS_TABLE}#{w}"

  # Close the connection
  conn.close

  return res
end

###############################################################################
# Main "program code"

# Initiate the script (check arguments etc) 
init

# Run the main "program"
main
