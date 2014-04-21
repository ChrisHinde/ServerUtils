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
$delete_accounts = false


# Method for printing the "usage information"
def usage
  puts "USAGE:"
  puts "\t" + __FILE__ + " DOMÄN [ARGUMENT]"
  #print "\n"
  #puts "Exempel:"
  #puts "\t" + __FILE__ + " arthur@example.com -n \"Arthur Dent\" -p 12qwaszx"
  #puts "\t" + __FILE__ + " arthur@example.com -n \"Arthur Dent\" -G"
  puts "\nArgument:"
  puts "\t-h, --help\t\t\tVisa denna information"
  puts "\t-s, --simulate\t\t\tSimulera allt, gör inga ändringar i filsystem eller databas"
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
    o.on('-s',          '--simulate')         { |b| $simulate = b }
    o.on('-h',          '--help')             { usage }
    o.parse!
  end
  
  # Get the e-mail address from the arguments
  begin 
    $domain = ARGV.pop
  end until ( $domain == nil ) || ( $domain[0] != '-' )

  # If we didn't get an address, output the usage info
  usage unless $domain

end

# The main method, it just calls other methods
def main
  # Say hello to the user
  puts "Ta bort domänen '#{$domain}'".green
  puts "-----------------------\n".green

  # If this isn't a simulation ...
  unless $simulate
    # ... check if the script is running as root, if it isn't: warn the user!
    puts "OBS!!!\nDetta kommando bör köras som root!\n".pink unless is_root?
  else
    puts "Kör i simuleringsläge!".pink
  end

  # List the accounts
  delete_domain $domain
end



# "Entry point" for deleting a domain
def delete_domain domain_name
  # Get the domain info
  domain = get_domain domain_name

  # Ask the user if the user is sure
  puts "Kommer att ta bort domänen för #{domain_name}!".yellow
  begin
    ans = ask_user "Är du helt säker på att du vill ta bort domänen? [ja/j] ", false
  end while ans == ""

  exit unless ['y', 'j', 'yes', 'ja'].include? ans.downcase
  
  begin
    ans = ask_user "Vill du även ta bort alla tillhörande konton? [ja/j] ", false
  end while ans == ""

  $delete_accounts = ['y', 'j', 'yes', 'ja'].include? ans.downcase

  # Do the deletion, one step at a time
  delete_db_post domain
  delete_directory domain if $delete_accounts
end

# Method that removes the domain from the db
def delete_db_post domain
  # Tell the user
  puts "> Tar bort domänen från databasen".green

  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  # Delete the domain
  conn.exec "DELETE FROM #{DB_DOMAINS_TABLE} WHERE domain = '#{domain['domain']}'" unless $simulate

  # Should we also delete the accounts for the domain?
  if $delete_accounts
    # Tell the user
    puts "> Tar bort tillhörande e-postkonton från databasen".green
    # Delete the accounts
    conn.exec "DELETE FROM #{DB_ACCOUNTS_TABLE} WHERE userid LIKE '%@#{domain['domain']}'" unless $simulate
  end

  # Close the connection
  conn.close
end

# Method that removes the domain from the file system
def delete_directory domain
  # Use FileUtils
  fu = FileUtils
  # If we're just running as a simulation
  if $simulate
    # Use ::DryRun, that just echoes the commands, instead of the normal FileUtils
    fu = FileUtils::DryRun # ::DryRun / ::NoWrite
  end

  # Tell the user
  puts "> Tar bort domänen från filsystemet".green

  # Build the paths
  mail_dir = BASE_PATH_MAIL + domain['domain']
  home_dir = BASE_PATH_HOME + domain['domain']

  # Remove the directories
  fu.rm_r mail_dir
  fu.rm_r home_dir
end

# Method for retrieving info about a email account
def get_domain domain

  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  # Get the info on the domain from the DB
  res = conn.exec "SELECT * FROM #{DB_DOMAINS_TABLE} WHERE domain = '#{domain}'"

  # Close the connection
  conn.close

  # The query resulted in nothing?!
  unless res.ntuples > 0
    puts "Kunde inte hitta domänen '#{domain}'!".red
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
