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
  #print "\n"
  #puts "Exempel:"
  #puts "\t" + __FILE__ + " arthur@example.com -n \"Arthur Dent\" -p 12qwaszx"
  #puts "\t" + __FILE__ + " arthur@example.com -n \"Arthur Dent\" -G"
  puts "\nArgument:"
  puts "\t-h, --help\t\t\tVisa denna information"
  #print "\n"

  #puts "\t-n, --name NAMN\t\t\tAnge NAMN som fullt namn för e-postkontot"

  # We also exit the script here..
  exit(0)
end

# Does all the initial processing
def init
  # Validate and parse the flags
  OptionParser.new do |o|
#    o.on('-n NAME',     '--name NAME')        { |n| $name = n }
    o.on('-h',          '--help')             { usage }
    o.parse!
  end
end


# The main method, it just calls other methods
def main
  # Say hello to the user
  puts "Listar existerande e-postkonton".green
  puts "-----------------------\n".green

  # List the accounts
  list_accounts
end


# Method that lists the accounts
def list_accounts
  # Get the accounts from the database
  accounts = get_accounts

  # Figure out the "widest" value in each column
  l = { :user => [6], :name => [4], :uid => [3], :gid => [3], :home => [7], :mail => [8] }
  accounts.each { |t|
    l[:user] << t['userid'].length
    l[:name] << t['realname'].length
    l[:uid]  << t['uid'].length
    l[:gid]  << t['gid'].length
    l[:home] << t['home'].length
    l[:mail] << t['mail'].length
  }

  f_str = "| %-" + l[:user].max.to_s + "s | %-" + l[:name].max.to_s + "s | %-" + l[:uid].max.to_s + "s |" +
            " %-" + l[:gid].max.to_s + "s | %-" + l[:home].max.to_s + "s | %-" + l[:mail].max.to_s + "s |"

  # Output the table with users
  puts f_str % [ 'E-post', 'Namn', 'UID', 'GID', 'Hemmapp', 'Mailmapp' ] # Heading
  l.each { |k,v|
    print "|-"
    v.max.times { print "-" }
    print "-"
  }
  puts "|"

  # Output the rows with data
  accounts.each { |t|
    puts f_str % [ t['userid'], t['realname'], t['uid'], t['gid'], t['home'], t['mail'] ]
  }

  print "\n"
end

# Method that retrieves the accounts
def get_accounts
  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  # Insert the user into the correct table
  res = conn.exec "SELECT * FROM #{DB_ACCOUNTS_TABLE}"

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
