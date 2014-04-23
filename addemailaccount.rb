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
$email = nil
$email_user = ''
$email_domain = ''
$password = nil
$enc_password = nil
$generate = false
$name = ''
$user_path = ''
$uid = DEFAULT_ID
$gid = DEFAULT_ID
$home = ''
$random_char_password = false
$save_file = false
$ask_for_info = false

# Method for printing the "usage information"
def usage
  puts "USAGE:"
  puts "\t" + __FILE__ + " [E-POST] [ARGUMENT]"
  print "\n"
  puts "Exempel:"
  puts "\t" + __FILE__ + " arthur@example.com -n \"Arthur Dent\" -p 12qwaszx"
  puts "\t" + __FILE__ + " arthur@example.com -n \"Arthur Dent\" -G"
  puts "\nArgument:"
  puts "\t-h, --help\t\t\tVisa denna information"
  puts "\t-s, --simulate\t\t\tSimulera allt, gör inga ändringar i filsystem eller databas"
  print "\n"
  
  puts "\t-n, --name NAMN\t\t\tAnge NAMN som fullt namn för e-postkontot"
  puts "\t-u, --uid UID\t\t\tAnge ett UID för e-postkontot"
  puts "\t-g, --gid GID\t\t\tAnge ett GID för e-postkontot"
  puts "\t-i, --guid ID\t\t\tAnge samma ID för både UID och GID för e-postkontot"
  puts "\t-p, --password PASSWORD\t\tAnge PASSWORD som lösenord för e-postkontot (annars fråga)"
  puts "\t-G, --generate\t\t\tGenerera ett lösenord för e-postkontot (annars fråga)"
  puts "\t-r, --random\t\t\tGenerar lösenordet med enbart slumpade tecken (snabbare, annars en slumpad mening med engelska ord)"
  puts "\t-S, --save [FIL]\t\tSparar info om användare (okrypterat lösenord etc) till FIL (eller E-POST.sec om inte angett). OBS! Använd med eftertanke!"
  puts "\t-H, --home HOME\t\t\tAnge HOME som mapp för mailkorgen (EJ IMPLEMENTERAT ÄN!)"

  # We also exit the script here..
  exit(0)
end

# Does all the initial processing
def init
  # Validate and parse the flags
  OptionParser.new do |o|
    o.on('-n NAME',     '--name NAME')        { |n| $name = n }
    o.on('-u UID',      '--uid UID')          { |uid| $uid = uid }
    o.on('-g GID',      '--gid GID')          { |gid| $gid = gid }
    o.on('-i ID',       '--guid ID')          { |id| $uid = id; $gid = id }
    o.on('-p PASSWORD', '--pass PASSWORD')    { |password| $password = password }
    o.on('-G',          '--generate')         { |b| $generate = b }
    o.on('-r [LENGTH]', '--random [LENGTH]')  { |l| $random_char_password = l }
    o.on('-H HOME',     '--home HOME')        { |h| $home = h }
    o.on('-S [FILE]',   '--save [FILE]')      { |f| $save_file = f }
    o.on('-s',          '--simulate')         { |b| $simulate = b }
    o.on('-h',          '--help')             { usage }
    o.parse!
  end

  # Make shure we have nice values later on
  $random_char_password = true if $random_char_password.nil?
  $save_file            = true if $save_file.nil?

  # Get the e-mail address from the arguments
  begin 
    $email = ARGV.pop
  end until ( $email == nil ) || ( $email[0] != '-' )

  # If this isn't a simulation ...
  unless $simulate
    # ... check if the script is running as root, if it isn't: warn the user!
    puts "OBS!!!\nDetta kommando bör köras som root!\n".pink unless is_root?
  else
    puts "Kör i simuleringsläge!".pink
  end

  # If we didn't get an address, output the usage info
  unless $email
    $ask_for_info = true
    return
  end

  check_email or exit(65)
end

# The main method, it just calls other methods
def main_def
  # Say hello to the user
  puts "Skapar ett e-postkonto för '#{$email}'"
  puts "-----------------------\n"
  
  handle_password

  print "\n"

  create_directories

  add_to_database

  save_to_file if $save_file
end


# The main method, it just calls other methods
def main_ask
  # Say hello to the user
  puts "Lägg till ett e-postkonto"
  puts "-----------------------\n"

  # Ask for a e-mailaddress, keep going if it's not valid
  begin
    $email = ask_user 'Vilken e-postadress vill du lägga till? ', false
  end until check_email

  # Ask the user for a name (accept empty)
  $name = ask_user 'Ange användarens namn (Kan vara tomt): ', false

  # Ask the user how we should do with the password
  pass_do = ask_user 'Hur vill du göra med lösenordet? [g = generera, r = generera med slumpade tecken, A = Ange ett lösenord] ', false

  # Set the appropriate "flags"
  case pass_do
  when "g"
    $generate = true
  when "r", "gr"
    $generate = true
    $random_char_password = true
  end

  handle_password

  print "\n"

  create_directories

  add_to_database

  # Ask the user if we should save the info to a file
  ans = ask_user "Vill du spara användarinformationen till en fil? [ja/j/NEJ] ", false

  save_file = ['y', 'j', 'yes', 'ja'].include? ans.downcase
  
  save_to_file if save_file
end

def check_email
  # We only want lowercase!
  $email.downcase!

  # Scan the address to get the different parts (also very basic validation)
  email_parts = $email.scan(/^(.+)@(.+)\.([a-z]{2,4})$/).flatten

  # If we have less than 3 parts, it's not a valid e-mail address
  if email_parts.length < 3
    puts "Det här ser inte ut som en giltig e-postadress: '#{$email}'!".red
    return false
  end

  # Store the parts of the address in appropriate variables
  $email_user = email_parts[0]
  $email_domain = email_parts[1] + '.' + email_parts[2]

  return true
end

# Handles all the things that has to do with the password
def handle_password
  # If the password already isn't set already
  unless $password
    # Should we generate a password
    if $generate
      # Tell the user what's going on
      puts "> Genererar ett lösenord (Kan ta några sekunder)".green

      # Check if $random_charpassword is a a numeric string, if so use t
      num = ($random_char_password.is_a? String and is_numeric? $random_char_password) ? $random_char_password.to_i : 16
      # Generate the password
      $password = generate_password $random_char_password, num
      $password.strip!

      # Give the generated password to the user
      puts "Det genererade lösenordet är: " + $password.yellow
    # We shouldn't generate a password
    else
      # Ask the user for the password ...
      begin
        # Ask for password and confirmation
        pass1 = ask_user("Ange ett lösenord: ".yellow)
        pass2 = ask_user("\nAnge lösenordet igen: ".yellow)
        print "\n"

        # Tell the user that the passwords didn't match, if they aren't identical
        puts "Lösenorden du angav är inte identiska!\nVänligen försök igen!".pink if ( pass1 != pass2 )
      end until ( pass1 == pass2 ) # Continue until the passwords match

      # If we didn't get a password
      if ( pass1 == "" )
        # Give the user a message and stop the script
        puts "\nInget lösenord angavs, avbryter skriptet!".pink
        exit(1)
      end

      # Store the password in the global variable
      $password = pass1.strip
    end
  end

  # Encrypt the password
  $enc_password = encrypt_password($password)
end

# Create the directories/mailboxes for the e-mail account
def create_directories
  # Use FileUtils
  fu = FileUtils
  # If we're just running as a simulation
  if $simulate
    # Use ::DryRun, that just echoes the commands, instead of the normal FileUtils
    fu = FileUtils::DryRun # ::DryRun / ::NoWrite
  end

  # Get the default user path ...
  $user_path = USER_PATH
  # Replace the placeholders with the user name and domain
  $user_path['%user'] = $email_user
  $user_path['%domain'] = $email_domain

  # Concat the paths of the directories we should create
  mail_dir = BASE_PATH_MAIL + $user_path 
  home_dir = BASE_PATH_HOME + $user_path

  # Tell the user what's going on
  puts "> Skapar kataloger för e-postkontot: #{mail_dir}, #{home_dir}".green

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

# Add the e-mail account to the database
def add_to_database
  # Tell the user what's going on
  puts "> Ansluter till databasen".green
  # Connect to the database
  conn = PG.connect( dbname: DB_DATABASE_NAME, user: DB_USER, password: DB_PASSWORD )

  # Tell the user what's going on
  puts "> Lägger till användaren i databasen".green
  # Insert the account into the correct table
  conn.exec_params "INSERT INTO #{DB_ACCOUNTS_TABLE} (userid, password, realname, uid, gid, home, mail)" +
                      " VALUES ($1, $2, $3, $4, $5, $6, $6)",
                    [$email, $enc_password, $name, $uid, $gid, $user_path] unless $simulate

  # Tell the user what's going on
  puts "> Kopplar från databasen".green
  # Close the connection
  conn.close
end

# Save the account information to a file
def save_to_file
  filename = $email + '.sec'

  # If we got a filename, use it
  filename = $save_file if $save_file.is_a? String

  # Tell the user what's going on
  puts "> Skriver användarinformation till filen ".green + filename.yellow

  # Open a "file stream"
  File.open(filename, 'w') {
    |f|
    f.write "<" + $name + "> " unless $name == ''
    f.write $email + "\n"
    f.write $password + "\n"
  } unless $simulate
end


###############################################################################
# Main "program code"

# Initiate the script (check arguments etc) 
init

# Run the main "program"
if $ask_for_info
  main_ask
else
  main_def
end
