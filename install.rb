#!/usr/bin/env ruby
# encoding: utf-8

# Script for installing the scripts of ServerUtils (su)
# Created by Christopher Hindefjord - chris@hindefjord.se - http://chris@hindefjord.se - 2014
# Licensed under the MIT License (see LICENSE file)

require 'optparse'
require 'io/console'
require 'fileutils'

require_relative 'su_lib.rb'
include ServerUtils_Lib

DEF_INSTALL_DIR = '/usr/bin'
CONFIG_FILE = 'su_config.rb'
$install_dir = DEF_INSTALL_DIR
$just_gen_conf = false
$dont_gen_conf = false
$install_req = false
$force_install = false
$keep_extensions = false
$simulate = false

$DEFAULT_ID   = 3001
$DB_NAME      = 'mails'
$DB_TABLE     = 'users'
$DB_USER      = 'mailwriter'
$DB_PASSWORD  = '12qwaszx'

# Method for printing the "usage information"
def usage
  puts "USAGE:"
  puts "\t" + __FILE__ + " [ARGUMENTS]"
  print "\n"
  puts "Installs the ServerUtils to the systems bin directory (Default: #{DEF_INSTALL_DIR}) and generates a config file."
  puts "If you don't like the default values for the config file you can use flags to change them (run " + "#{__FILE__} -sc".yellow + " to see the default config)"
  puts "The installation is based around the idea to keep all the SU files at one place (preferred if you cloned this via git)."
  puts "So the installation doesn't move or copy any files, instead it links them to their current location."
  puts "(So don't [re]move this directory after installation!)".red
  print "\n"
  puts "Example:"
  puts "\t" + __FILE__ + " -c"
  puts "\t" + __FILE__ + " -d /usr/sbin"
  puts "\nArguments:"
  puts "\t-h, --help\t\t\tShow this information"
  puts "\t-s, --simulate\t\t\tSimulate everything, don't making any real changes"
  print "\n"
  
  puts "\t-d, --dir DIR\t\t\tThe directory where the scripts should be installed (should be in $PATH) (defaults to #{DEF_INSTALL_DIR})"
  puts "\t\t\t\t\tWARNING: The script will stop with an error if the files already exists!".yellow
  puts "\t-c, --just-config\t\tJust generate the config file, don't do any installing!"
  puts "\t-n, --no-config\t\t\tDon't generate a config (useful if you already have a su_config.rb)'"
  puts "\t-r, --install-requirements\tInstall all the dependecies of SU (note: adds to the execution time!)"
  puts "\t-F, --force-install\t\tForces the install, overwrites files in the install directory if they exists (" + "Be careful with this!".red + ")"
  puts "\t-E, --keep-ext\t\t\tKeep the .rb extensions on the files when installing them"
  puts "\t\t\t\t\t(then you have to write " + "addemailaccount.rb arthur@example.com".yellow + " instead of " + "addemailaccount arthur@example.com".yellow + ")"
  print "\n"
  puts "\t-D, --db-name NAME\t\tSet the database name to NAME"
  puts "\t-t, --db-table TABLE\t\tSet the database table to TABLE"
  puts "\t-u, --db-user USER\t\tSet the database user to USER"
  puts "\t-p, --db-password PASSWORD\tSet the database password to PASSWORD"
  puts "\t-i, --id ID\t\t\tSet the default id (gid & uid) to ID (could be numeric or name [like " + "vmail".yellow + "], used to set the system/file owner of the mailboxes)"

  # We also exit the script here..
  exit(0)
end

# Does all the initial processing
def init
  # Validate and parse the flags
  OptionParser.new do |o|
    o.on('-D NAME',     '--db-name NAME')          { |n| $DB_NAME = n }
    o.on('-t TABLE',    '--db-table TABLE')        { |t| $DB_TABLE = t }
    o.on('-u USER',     '--db-user USER')          { |u| $DB_USER = u }
    o.on('-p PASSWORD', '--db-password PASSWORD')  { |p| $DB_PASSWORD = p }
    o.on('-i ID',       '--default-id ID')         { |i| $DEFAULT_ID = i }
    o.on('-d DIR',      '--dir DIR')               { |d| $install_dir = d }
    o.on('-E',          '--keep-ext')              { |b| $keep_extensions = b }
    o.on('-F',          '--force-install')         { |b| $force_install = b }
    o.on('-c',          '--just-config')           { |b| $just_gen_conf = b; }
    o.on('-r',          '--install-requirements')  { |b| $install_req = b; }
    o.on('-n',          '--no-config')             { |b| $dont_gen_conf = true } # b assingment didn't work!? (b was false)
    o.on('-s',          '--simulate')              { |b| $simulate = b }
    o.on('-h',          '--help')                  { usage }
    o.parse!
  end

  # We can't do anything if we should both skip the config file and just generate the config file
  if $just_gen_conf and $dont_gen_conf
    puts "Conflicting flags: -n/--no-config and -c/--just-config".red
    puts "Since we can't both generate just the config and skip the generation of it, the script will now quit!".red
    exit(65)
  end

  puts "RUNNING IN SIMULATION MODE!".pink if $simulate

  # If this isn't a simulation ...
  unless $simulate
    # ... check if the script is running as root, if it isn't: warn the user!
    puts "WARNING!!!\nThis script should be run with root privileges!\n".pink unless is_root?
  end

  # Add a / to the end of the install path if it's missing
  $install_dir << '/' unless $install_dir[-1,1] == '/'

  # Add quotes if the ID is a name
  $DEFAULT_ID = "'#{$DEFAULT_ID}'" unless is_numeric? $DEFAULT_ID
end

# The main method, it mainly just calls other methods
def main
  generate_config unless $dont_gen_conf

  if $just_gen_conf
    puts "\nSkips installing, just generated the config file!".pink
    exit(0)
  end
  
  install_dependencies if $install_req

  install_to_directory
end


# Method for generating the config file
def generate_config

  # Tell the user what's going on
  puts "> Generating the config file".green

  config = <<CONF_END

# Configuration for the ServerUtility
# Created by Christopher Hindefjord - chris@hindefjord.se - http://chris@hindefjord.se - 2014
# Licensed under the MIT License (see LICENSE file)

DEFAULT_ID = #{$DEFAULT_ID}
BASE_PATH = '/home/mailboxes/'
BASE_PATH_MAIL = BASE_PATH + 'maildir/'
BASE_PATH_HOME = BASE_PATH + 'home/'
USER_PATH = '%domain/mails/%user'
MAILBOX_RIGHTS = 0770 # "ug=wrx"
DB_DATABASE_NAME = '#{$DB_NAME}'
DB_ACCOUNTS_TABLE = '#{$DB_TABLE}'
DB_USER = '#{$DB_USER}'
DB_PASSWORD = '#{$DB_PASSWORD}'

CONF_END

  # If this is a simulation
  if $simulate
    puts "We're not writing to a file, so here's the config file in text:".green
    # Just output the config file
    print config.yellow
  # Not a simulation
  else
    # Open a "file stream" and write to it
    File.open(CONFIG_FILE, 'w') { |f| f.write config }

    # Tell the user
    puts "> Wrote the config to '#{CONFIG_FILE}'.".green
  end

end

# Method for installing the scripts
def install_to_directory
  # Get the current directory
  curr_dir = FileUtils::pwd + '/'
  # Use FileUtils
  fu = FileUtils
  # If we're just running as a simulation
  if $simulate
    # Use ::DryRun, that just echoes the commands, instead of the normal FileUtils
    fu = FileUtils::DryRun # ::DryRun / ::NoWrite
  end

  # Tell the user
  puts "Installing the files to ".green + $install_dir.yellow
  puts " (Keeping the .rb extensions) ".green if $keep_extensions

  # Go through the files
  files = ['listemailaccounts.rb','addemailaccount.rb','generate_password.rb']
  files.each { |f|
    # Remove the extenstion (unless we should keep it)
    nf = $keep_extensions ? f : f[0..-4]

    # Tell the user
    puts "> Linking ".green + "#{curr_dir}#{f}".yellow + ' to '.green + "#{$install_dir}#{nf}".yellow

    if $force_install
      puts "Forcing the install of #{nf}!".red
      # Link the file
      fu.ln_sf curr_dir + f, $install_dir + nf
    else
      begin
        # Link the file
        fu.ln_s curr_dir + f, $install_dir + nf
      rescue Exception => e
        puts "Couldn't link the file:".pink
        puts e.message.red
        next
      end
    end

    puts "> Adding 'execute permission' to the file".green
    # adding "execute permission"
    fu.chmod "a+x", $install_dir + nf
  }

end

# Method that install dependencies
def install_dependencies

  # sudo apt-get install postgresql-client libpq5 libpq-dev
  # sudo apt-get install ruby1.9-dev
  # sudo apt-get install make
  
  # Install the pg gem
  puts "> Installing the pg gem".green
  system "gem install pg" unless $simulate
  
  # Install the nokogiri gem
  puts "> Installing the nokogiri gem".green
  system "gem install nokogiri" unless $simulate

end

###############################################################################
# Main "program code"

# Initiate the script (check arguments etc) 
init

# Run the main "program"
main


