require 'ladder'

bot = nil



USER_ID_HOLDER = {gbot_id: nil}
FIRST_GBOT_MESSAGE_HOLDER = {first_gbot_message_id: nil}



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
      TEST_COMMAND_STRING = "5 results for test"
      ERR_CODE_0 = "search string for gbot is not a string"# ,
      ERR_CODE_1 = "respoonse not delivered within 1 second"# ,
      ERR_CODE_2 = "Gbot discord user id was not configured, start the assignment after bot restart by '!pipeline gbot-id-capture"# ,
      ERR_CODE_3 = "Gbot didn't respond within timeframe"# ,
      ERR_CODE_4 = "Gbot answered more than once within timeframe (this bot must run in a channel where only this bot is allowed to write messages to gbot)"# ,
      ERR_CODE_5 = "ID of all following gbot messages must not equal the id of the first gbot message"
      ERR_CODE_6 = "ID of first gbot message received by this program must not be nil"
      



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
    MESSAGE = "gbot: #{TEST_COMMAND_STRING} | filter by google page speed score | top 1"
  # end




  # §(ONLY_SAVE_STATE_VIA_ONE_IVAR: :@queue, QUEUE_IMPLEMENTATION) do
    class Pipeline
      def initialize
        @queue = []
      end

      def add(execute)
        # §(USE_PUSH_OVER_UNSHIFT_FOR: QUEUE_IMPLEEMENTATION)
          @queue.push(execute)
       # end
      end

      def run
        last_item = nil
        while @queue.any?
          last_item = yield(@queue.shift, @queue.size)
        end
      end

      def inspect
        """
          First run command #{@queue[0]}
          Second run command #{@queue[1]}
          Third run command #{@queue[2]}
        """
      end
    end
  # end
  

  module Pipeline::ExpectResponseWithin
    module ClassMethods
      def timeframe_for_response=(timeframe_in_seconds)
        @timeframe_in_seconds = timeframe_in_seconds
      end
    end
  end
  
  class GbotCommandResponseCapture
    extend Pipeline::ExpectResponseWithin::ClassMethods
  
    @user_id_of_message_to_be_captured = USER_ID_HOLDER
    self.timeframe_for_response = 1 # Second
    
    
    def pump(discord_listener)
      fail ERR_ID_2 if self.class.instance_variable_get(:@user_id_of_message_to_be_captured)[:gbot_id].nil?
      
      
      gbot_id = self.class.instance_variable_get(:@user_id_of_message_to_be_captured)[:gbot_id]
      
      message = nil
      messages_by_gbot_in_timeframe = 0
      before = Time.now.to_i
      while (Time.now.to_i - before) < self.class.timeframe_for_response
        message_data = discord_listener.pop
        fail ERR_ID_6 if FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id].nil?
        fail ERR_ID_5 if message_data['id'] == FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id]
        
        if message_data['author']['id'] == gbot_id
          messages_by_gbot_in_timeframe += 1
          
          message = message_data['content']
        end
      end
      
      fail ERR_ID_3 if message.nil?
      fail ERR_ID_4 if messages_by_gbot_in_timeframe > 1
      
      @message = message
    end
    
    def response
      @message
    end
  end
  
  
  
  discord_messages = []
  
  
    ladder { |data|
      discord_messages.push(data)
    }
  
  def get_gbot_message
    capture = GbotCommandResponseCapture.new
    
    
    capture.pump(discord_messages)
    
    capture.response
  end

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


bot.message(with_textt: '!pipeline gbot-id-capture') do |event|
  event.respond("Type start to begin")
  event.user.await(:start) do |start_event|
    event.respond('gbot: get-id')
     #
    # message = nil
    # messages_by_gbot_in_timeframe = 0
    # before_t = Time.now
    # before = Time.now.to_i
    #
       
    ladder { |data|
      # unless discord_messages.include?(data)
      #   discord_messages.push(data)
      # end
      
      
      # event.respond(data.inspect)
      
      # while (Time.now.to_i - before) < 10000
      #   puts "test #{Time.now.to_i - before}"
      #   message_data = discord_messages.pop
      #
      #   sleep 0.5
      #
      #
      #   next if message_data.nil?
      #
      #
        if(data['author']['username'] == 'GBot')
          event.respond(data.inspect)
          
          USER_ID_HOLDER[:gbot_id] = data['author']['id']
          FIRST_GBOT_MESSAGE_HOLDE[:first_gbot_message_id] = data['id']
        end
      # end
    }
    
    
  end
end



bot.message(with_text: 'pipeline:') do |event|
  (event.respond("Please first initialize via !pipeline gbot-id-capture") && break) if USER_ID_HOLDER[:gbot_id].nil?


      # return event.user.sname    
    pipe_parts = split_into_pipe_parts(message: MESSAGE, pipe_unicode_symbol: '|')

    event.respond pipe_parts.inspect

    pipeline = Pipeline.new
    pipe_parts.each do |pipe_part| pipeline.add(pipe_part) end

    event.respond(pipeline.inspect)

    pipeline.run { |message, left_commands_count|
      event.respond("Commands to be run after this one: #{left_commands_count}, now running:")

      # command = CommandChooser.new(message).command

      # command.timed do
        event.respond(message) # if command.bot_2_bot?


        # if command.requires_gbot_answer_command?
            # until next_message_is_gbot_answer_limited_to_1_via_50_MILLISECOND_DEBOUNCE_INTO_THE_PAST_AND_FUTURE
            # https://github.com/meew0/discordrb/blob/master/examples/ping_with_respond_time.rb
                event.respond(get_gbot_message)
            # end
        # end
      # end



    }
end

bot.run

# def gbot(search)
#   wait_for_response(starts_with: 'gbot:')
# end






# module SendMessageAndProcessBotResponseWithin5Seconds
#   module Pipeline;end
 

#   class Pipeline::FailIfResponseCantBeDeliveredWithin1Second
#   end
# end





















































puts GbotCommandForBot2Bot.new(TEST_COMMAND_STRING).to_discord_message





















bot.run
