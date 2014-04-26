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

$email = nil

# Method for printing the "usage information"
def usage
  puts <<EOU
USAGE:
  #{__FILE__} E-POST [ARGUMENT]

Ta bort e-postkontot för E-POST

Argument:
  -h, --help        Visa denna information
  -s, --simulate    Simulera allt, gör inga ändringar i filsystem eller databas
EOU

  # We also exit the script here..
  exit(0)
end

# Does all the initial processing
def init
  # Validate and parse the flags
  OptionParser.new do |o|
#    o.on('-n NAME',     '--name NAME')        { |n| $name = n }
    o.on('-s',          '--simulate')         { |b| $simulate = b }
    o.on('-h',          '--help')             { usage }
    o.parse!
  end
  
  # Get the e-mail address from the arguments
  begin 
    $email = ARGV.pop
  end until ( $email == nil ) || ( $email[0] != '-' )

  # If we didn't get an address, output the usage info
  usage unless $email

  # Make shure we have nice values later on
  $random_char_password = true if $random_char_password.nil?
  $save_file            = true if $save_file.nil?

end


# The main method, it just calls other methods
def main
  # Say hello to the user
  puts "Ta bort e-postkontot '#{$email}'".green
  puts "-----------------------\n".green

  # Scan the address to get the different parts (also very basic validation)
  email_parts = $email.scan(/^(.+)@(.+)\.([a-z]{2,4})$/).flatten

  # If we have less than 3 parts, it's not a valid e-mail address
  if email_parts.length < 3
    puts "Det här ser inte ut som en giltig e-postadress: '#{$email}'!".red
    exit(65)
  end

  # If this isn't a simulation ...
  unless $simulate
    # ... check if the script is running as root, if it isn't: warn the user!
    puts "OBS!!!\nDetta kommando bör köras som root!\n".pink unless is_root?
  else
    puts "Kör i simuleringsläge!".pink
  end

  # Delete the account
  delete_account $email
end

# "Entry point" for deleting an account
def delete_account email
  # Get the account info
  account = get_account_for email

  # Include the name, if there is any
  n = account['realname'] == '' ? '' : "<#{account['realname']}> "

  # Ask the user if the user is sure
  puts "Kommer att ta bort kontot (inklusive alla mail etc) för #{n}#{email}!".yellow
  begin
    ans = ask_user "Är du helt säker på att du vill ta bort kontot? [ja/j] ", false
  end while ans == ""

  exit unless ['y', 'j', 'yes', 'ja'].include? ans.downcase

  # Do the deletion, one step at a time
  delete_db_post account
  delete_directories account
end

# Method that removes the account from the db
def delete_db_post account
  # Tell the user
  puts "> Tar bort kontot från databasen".green

  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  # Delete the account
  res = conn.exec "DELETE FROM #{DB_ACCOUNTS_TABLE} WHERE userid = '#{account['userid']}'" unless $simulate

  # Close the connection
  conn.close
end

# Method that removes the account from the file system
def delete_directories account
  # Use FileUtils
  fu = FileUtils
  # If we're just running as a simulation
  if $simulate
    # Use ::DryRun, that just echoes the commands, instead of the normal FileUtils
    fu = FileUtils::DryRun # ::DryRun / ::NoWrite
  end
  
  # Tell the user
  puts "> Tar bort kontot från filsystemet".green

  # Build the paths
  mail_dir = BASE_PATH_MAIL + account['mail']
  home_dir = BASE_PATH_HOME + account['home']

  # Remove the directories
  fu.rm_r mail_dir
  fu.rm_r home_dir
end

# Method for retrieving info about a email account
def get_account_for email

  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  # Get the info on the account from the DB
  res = conn.exec "SELECT * FROM #{DB_ACCOUNTS_TABLE} WHERE userid = '#{email}'"

  # Close the connection
  conn.close

  # The query resulted in nothing?!
  unless res.ntuples > 0
    puts "Kunde inte hitta ett konto för e-postadressen '#{email}'!".red
    exit
  end

  return res[0]
end

###############################################################################
# Main "program code"

# Initiate the script (check arguments etc) 
init

# Run the main "program"
main
