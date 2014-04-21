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

$simulate  = false
$domain    = ''
$transport = 'virtual:'
$uid       = DEFAULT_ID
$gid       = DEFAULT_ID

# Method for printing the "usage information"
def usage
  puts "USAGE:"
  puts "\t" + __FILE__ + " DOMÄN [ARGUMENT]"
  print "\n"
  puts "Exempel:"
  puts "\t" + __FILE__ + " example.com"
  #puts "\t" + __FILE__ + " example.com -n \"Arthur Dent\" -G"
  puts "\nArgument:"
  puts "\t-h, --help\t\t\tVisa denna information"
  puts "\t-s, --simulate\t\t\tSimulera allt, gör inga ändringar i filsystem eller databas"
  print "\n"
  
  #puts "\t-t, --transport TRANSPORT\t\t\tAnge NAMN som fullt namn för e-postkontot"
  puts "\t-u, --uid UID\t\t\tAnge ett UID för katalogerna"
  puts "\t-g, --gid GID\t\t\tAnge ett GID för katalogerna"
  puts "\t-i, --guid ID\t\t\tAnge samma ID för både UID och GID för katalogerna"

  # We also exit the script here..
  exit(0)
end

# Does all the initial processing
def init
  # Validate and parse the flags
  OptionParser.new do |o|
    #o.on('-t TRANSPORT',  '--transport TRANSPORT')  { |t| $transport = t }
    o.on('-u UID',        '--uid UID')              { |uid| $uid = uid }
    o.on('-g GID',        '--gid GID')              { |gid| $gid = gid }
    o.on('-i ID',         '--guid ID')              { |id| $uid = id; $gid = id }
    o.on('-s',            '--simulate')             { |b| $simulate = b }
    o.on('-h',            '--help')                 { usage }
    o.parse!
  end

  # Get the e-mail address from the arguments
  begin 
    $domain = ARGV.pop
  end until ( $domain == nil ) || ( $domain[0] != '-' )

  # If we didn't get a domain, output the usage info
  usage unless $domain

  # If this isn't a simulation ...
  unless $simulate
    # ... check if the script is running as root, if it isn't: warn the user!
    puts "OBS!!!\nDetta kommando bör köras som root!\n".pink unless is_root?
  else
    puts "Kör i simuleringsläge!".pink
  end

end


# The main method, it just calls other methods
def main
  # Say hello to the user
  puts "Skapar en e-postdomän för '#{$domain}'"
  puts "-----------------------\n"

  create_directory

  add_to_database
end

# Create a directories for the domain
def create_directory
  # Use FileUtils
  fu = FileUtils
  # If we're just running as a simulation
  if $simulate
    # Use ::DryRun, that just echoes the commands, instead of the normal FileUtils
    fu = FileUtils::DryRun # ::DryRun / ::NoWrite
  end

  # Get the default user path ...
  user_path = USER_PATH
  # Replace the placeholders with the domain
  user_path['%user'] = ''
  user_path['%domain'] = $domain

  # Concat the paths of the directories we should create
  mail_dir = BASE_PATH_MAIL + user_path 
  home_dir = BASE_PATH_HOME + user_path

  puts "> Skapar kataloger".green

  # Create the directories (the full path)
  fu.mkdir_p mail_dir
  fu.mkdir_p home_dir

  # Tell the user what's going on
  puts "> Ändrar ägare och rättigheter för katalogerna".green

  # Check to see if we have root privileges
  if is_root?
    # Change the ownerships of the directories
    fu.chown_R $uid, $gid, mail_dir
    fu.chown_R $uid, $gid, home_dir
  # not root!
  else
    # Let the user know that we couldn't change the owner of the directories
    puts "\nOBS!!!".red
    puts "Kan inte ändra ägare och grupp för katalogerna, då skriptet inte körs som root!".red
    puts "Vänligen se till att katalogerna får rätt ägare genom att köra följande kommandon som root:".red
    print "\n"
    # Use ::DryRun to let the user know what commands to run
    FileUtils::DryRun.chown_R $uid, $gid, mail_dir
    FileUtils::DryRun.chown_R $uid, $gid, home_dir

    print "\n"
  end

  # Change the rights of the directories
  fu.chmod_R MAILBOX_RIGHTS, mail_dir
  fu.chmod_R MAILBOX_RIGHTS, home_dir
end

def add_to_database
  # Tell the user what's going on
  puts "> Ansluter till databasen".green
  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  # Tell the user what's going on
  puts "> Lägger till användaren i databasen".green
  # Insert the account into the correct table
  conn.exec_params "INSERT INTO #{DB_DOMAINS_TABLE} (domain, transport)" +
                      " VALUES ($1, $2)",
                    [$domain, $transport] unless $simulate

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
