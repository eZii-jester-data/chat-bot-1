module EZIIDiscordIntegration
  class CurlManager
    def initialize(website_urls)
      @website_urls
    end
    
    def start_calls_in_background
    end
    
    def wait_for_finish
      return self
    end
    
    def winner
      return 'test'
    end
    
    def inspect
      """
        EZIIDiscordIntegration::CurlManagers
        Binding: #{binding}
        File: #{__FILE__}
        
        
        inspect of EZIIDiscordIntegration::CurlManagers# -> @website_urls (# is the symbol for an instance -> method edge in ruby)
        
        
        #{@website_urls.inspect}
      """
    end
  end
end