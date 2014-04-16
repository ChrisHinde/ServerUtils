
# Method library for ServerUtils (su)
# Created by Christopher Hindefjord - chris@hindefjord.se - http://chris@hindefjord.se - 2014
# Licensed under the MIT License (see LICENSE file)

module ServerUtils_Lib
  EMAIL_REGEX = /^(?!(?:(?:\x22?\x5C[\x00-\x7E]\x22?)|(?:\x22?[^\x5C\x22]\x22?)){255,})(?!(?:(?:\x22?\x5C[\x00-\x7E]\x22?)|(?:\x22?[^\x5C\x22]\x22?)){65,}@)(?:(?:[\x21\x23-\x27\x2A\x2B\x2D\x2F-\x39\x3D\x3F\x5E-\x7E]+)|(?:\x22(?:[\x01-\x08\x0B\x0C\x0E-\x1F\x21\x23-\x5B\x5D-\x7F]|(?:\x5C[\x00-\x7F]))*\x22))(?:\.(?:(?:[\x21\x23-\x27\x2A\x2B\x2D\x2F-\x39\x3D\x3F\x5E-\x7E]+)|(?:\x22(?:[\x01-\x08\x0B\x0C\x0E-\x1F\x21\x23-\x5B\x5D-\x7F]|(?:\x5C[\x00-\x7F]))*\x22)))*@(?:(?:(?!.*[^.]{64,})(?:(?:(?:xn--)?[a-z0-9]+(?:-[a-z0-9]+)*\.){1,126}){1,}(?:(?:[a-z][a-z0-9]*)|(?:(?:xn--)[a-z0-9]+))(?:-[a-z0-9]+)*)|(?:\[(?:(?:IPv6:(?:(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){7})|(?:(?!(?:.*[a-f0-9][:\]]){7,})(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){0,5})?::(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){0,5})?)))|(?:(?:IPv6:(?:(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){5}:)|(?:(?!(?:.*[a-f0-9]:){5,})(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){0,3})?::(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){0,3}:)?)))?(?:(?:25[0-5])|(?:2[0-4][0-9])|(?:1[0-9]{2})|(?:[1-9]?[0-9]))(?:\.(?:(?:25[0-5])|(?:2[0-4][0-9])|(?:1[0-9]{2})|(?:[1-9]?[0-9]))){3}))\]))$/i

  # Generate a password for the user
  #
  # * *Args*:
  #   - +random_chars+  -> Generate a password with random characters (otherwise a password with four words)
  #   - +num+           -> The length of the password (if random characters)
  # * *Returns*:
  #   - The generated password
  def generate_password( random_chars = false, num = 16 )
    password = ''
    
    # Should it be generated with random characters
    if ( random_chars )
      # The characters to use
      cs = [*'0'..'9', *'a'..'z', *'A'..'Z','_','-','!','.','$']
      # Randomize
      password = num.times.map { cs.sample }.join
    # Otherwise use the "subroutine" genpass to generate a password with random words
    else
      # Call the "genpass subroutine"
      password = `./generate_password.rb`.downcase
    end
    
    return password
  end

  # Ask a question to the user
  #
  # * *Args*:
  #   - +prompt+ -> The prompt/question to show to the user
  # * *Returns*:
  #   - The string the user gave
  def ask_user(prompt="Password: ")
    print prompt
    STDIN.noecho(&:gets).strip
  end

  # Encrypt the password for storage in the database
  #
  # * *Args*:
  #   - +password+ -> The unencrypted password that should be encrypted
  # * *Returns*:
  #   - The encrypted password
  def encrypt_password(password)
    #return "{SHA512}" + Digest::SHA512.hexdigest("#{password}")
    # Use the doveadm utility to encrypt the password
    return %x[doveadm pw -s SHA512 -p '#{password}'].strip
  end

  # Check if the object (probably a string) is a number (ex: "42")
  #
  # * *Args*:
  #   - +obj+ -> The object to check
  # * *Returns*:
  #   - true if the object is numeric, false otherwise
  def is_numeric?(obj) 
     obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
  end

  # Check if the script is runned as root
  #
  # * *Returns*:
  #   - true if the the user is root
  def is_root?
    who = `whoami`
    who.strip!
    who == 'root'
  end

end

class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def pink
    colorize(35)
  end
end
