module EZIIDiscordIntegration
  class CurlManager
    def initialize(website_urls)
      @website_urls = website_urls.flatten
      @threads = {}
    end
    
    def start_calls_in_background
      @website_urls.each do |url|
        # tst = -> { `curl #{CGI.escape(url)} -s -o /dev/null -w  "%{time_starttransfer}\n"` }
        #
        # byebug
        #
        #
        
        thread = Thread.new do
          # §(INSECURE)
          
          @threads[thread] = [`curl '#{url}' -s -o /dev/null -w  "%{time_starttransfer}\n"`, url]
        end
        
        @threads[thread] = nil
      end
    end
    
    def wait_for_finish
      @threads.keys.each(&:join)
      
      return self
    end
    
    def winner
      return @threads.values.min_by do |value|
        fail ERR_ID_8 if !(value[0].to_f > 0)
        value[0].to_f
      end.inspect
    end
    
    def inspect
      """
        EZIIDiscordIntegration::CurlManagers
        Binding: #{binding}
        File: #{__FILE__}
        
        
        inspect of EZIIDiscordIntegration::CurlManagers# -> @website_urls (# is the symbol for an instance -> method edge in ruby)
        
        
        #{@website_urls.inspect}
        
        
        Threads
        
        #{@threads.inspect}
      """
    end
  end
end