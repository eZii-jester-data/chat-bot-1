

bot = nil







  # C_EXTENSION_SIGNATURE_FOR_THIS_IDEA = [:signing, 0]


  # def 🖊(*args)
  #   yield
  # end


  # 🖊(C_EXTENSION_SIGNATURE_FOR_THIS_IDEA: "https://github.com/tmm1/http_parser.rb/blob/master/ext/ruby_http_parser/ruby_http_parser.c#L211") do



  #   def §(*args)
  #     yield
  #   end

  #   # Manuel Arno Korfmann signature §

  #   TEST____ONLY____FETCHING_5_RESULTS_FROM_OTHER_BOT_USING_STATIC_QUERY = 0

  #   LAW_SET = [
  #     "Test-Bot-For-Implementing-Single-Usecase [Case: #1]",
  #     "MANUEL ARNO KORFMANN SIGNATURE",
  #     TEST____ONLY____FETCHING_5_RESULTS_FROM_OTHER_BOT_USING_STATIC_QUERY,
      TEST_COMMAND_STRING = "5 results for test",
  #     ERR_CODE_0 = "search string for gbot is not a string",
  #     ERR_CODE_1 = "respoonse not delivered within 1 second",



  #     NOT_SUITABLE_FOR_STAGING_WHEN = {ERR_CODE_1: "happens for over 2% of test cases"}
  #   ]

  #   # TEST____ONLY____FETCHING_5_RESULTS_FROM_OTHER_BOT_USING_STATIC_QUERY = 0


  #   # Manuel Arno Korfmann signature §set = law set = testing discord bots for communicating wiith other bots

  # end

  # TYPE(message: :not_blank, :not_empty_string)
    def split_into_pipe_parts(message: '', pipe_unicode_symbol: '|')
      message.split('|')
    end
  # END TYPE

  # MESSAGE = nil
  # §(TEST____ONLY____FETCHING_5_RESULTS_FROM_OTHER_BOT_USING_STATIC_QUERY) do
    
  #   MESSAGE = "gbot test | filter by google page speed score | top 1"
    MESSAGE = "gbot test | filter by google page speed score | top 1"
  # end


  class GbotCommandForBot2Bot
    def initialize(text)
      @text = text
    end
    
    def to_discord_message
      # fail "ERR_CODE: 0" if @text.is_a?(String).false?
      @text.to_s
    end
  end

  require 'discordrb'


# listening_bot = Discordrb::Bot.new token: ENV['BOT_TOKEN']


# bot = Discordrb::Commands::CommandBot.new token: ENV['BOT_TOKEN'], prefix: '!' do

#   bot.command 'pipeline' do |event|
#     # return event.user.sname    
#     pipe_parts = split_into_pipe_parts(message, '|')

#     return pipe_parts.inspect

#     pipe_parts.each do |pipe_part| pipeline.add(pipe_part) end
#   end

# end



bot = Discordrb::Bot.new token: ENV['BOT_TOKEN']

bot.message(with_text: 'pipeline:') do |event|
  # event.respond 'Pong!'


      # return event.user.sname    
    pipe_parts = split_into_pipe_parts(message: MESSAGE, pipe_unicode_symbol: '|')

    event.respond pipe_parts.inspect

    pipe_parts.each do |pipe_part| pipeline.add(pipe_part) end
end

bot.run

# def gbot(search)
#   wait_for_response(starts_with: 'gbot:')
# end




# class Pipeline
#   def initialize
#     @queue = []
#   end

#   def add(execute)
#     @queue.unshift(execute)
#   end

#   def run
#     last_item = nil
#     while @queue.still_items?
#       last_item = @queue.shift.do(last_item)
#     end
#   end
# end


# module SendMessageAndProcessBotResponseWithin5Seconds
#   module Pipeline;end
#   class Pipeline::ExpectResponseWithin
#   end

#   class Pipeline::FailIfResponseCantBeDeliveredWithin1Second
#   end
# end





















































puts GbotCommandForBot2Bot.new(TEST_COMMAND_STRING).to_discord_message





















bot.run
