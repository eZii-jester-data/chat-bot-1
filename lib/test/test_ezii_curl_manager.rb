require_relative '../ezii_curl_manager.rb'


cm = EZIIDiscordIntegration::CurlManager.new("teest")


fail if cm.nil?