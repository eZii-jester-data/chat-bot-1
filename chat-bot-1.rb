def §(*args)
  yield
end

# Manuel Arno Korfmann signature §

TEST____ONLY____FETCHING_5_RESULTS_FROM_OTHER_BOT_USING_STATIC_QUERY = 0

LAW_SET = [
  "Test-Bot-For-Implementing-Single-Usecase [Case: #1]",
  "MANUEL ARNO KORFMANN SIGNATURE",
  TEST____ONLY____FETCHING_5_RESULTS_FROM_OTHER_BOT_USING_STATIC_QUERY
]

# TEST____ONLY____FETCHING_5_RESULTS_FROM_OTHER_BOT_USING_STATIC_QUERY = 0


# Manuel Arno Korfmann signature §set = law set = testing discord bots for communicating wiith other bots


§(TEST____ONLY____FETCHING_5_RESULTS_FROM_OTHER_BOT_USING_STATIC_QUERY) do

  require 'discordrb'


  listening_bot = Discordrb::Bot.new token: ENV['BOT_TOKEN']


  bot = Discordrb::Commands::CommandBot.new token: ENV['BOT_TOKEN'], prefix: '!'

    bot.command :"gbot:" do |event|
      return event.user.name
    
    
      pipe_parts = split_into_pipe_parts(message, '|')
  
      pipe_parts.each do |pipe_part| pipeline.add(pipe_part) end
    end



    def wait_for_response(starts_with: nil)
    end
  
  end


  def gbot(search)
    wait_for_response(starts_with: 'gbot:')
  end


  bot.run


  class Pipeline
    def initialize
      @queue = []
    end
  
    def add(execute)
      @queue.unshift(execute)
    end
  
    def run
      last_item = nil
      while @queue.still_items?
        last_item = @queue.shift.do(last_item)
      end
    end
  end
end