#!/usr/bin/env ruby
# frozen_string_literal: true

require 'securerandom'
require 'digest'

# Load Rails environment
require_relative '../config/environment'

def update_user_password(user_id, new_password)
  user = User.find(user_id)
  
  # Generate new salt and hash password
  salt = SecureRandom.base64
  hashed_password = Digest::SHA1.hexdigest("#{new_password}#{salt}")
  
  # Update user password and salt
  user.update!(password: hashed_password, salt: salt)
  
  puts "✓ Password for user_id #{user_id} (#{user.username}) has been updated to '#{new_password}'"
rescue ActiveRecord::RecordNotFound
  puts "✗ User with ID #{user_id} not found"
rescue StandardError => e
  puts "✗ Error updating password: #{e.message}"
end

# Main execution
if ARGV.empty?
  puts "Usage: ruby #{__FILE__} <user_id> [password]"
  puts "Example: ruby #{__FILE__} 1 test"
  exit 1
end

user_id = ARGV[0].to_i
new_password = ARGV[1] || 'test'

update_user_password(user_id, new_password)
