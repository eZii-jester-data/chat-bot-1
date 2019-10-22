require 'ladder'
require 'discordrb'


def monkeypatching
  yield
end

monkeypatching do
module Discordrb
  # Represents a Discord bot, including servers, users, etc.
  class Bot

def handle_dispatch(type, data)
     # Check whether there are still unavailable servers and there have been more than 10 seconds since READY
     if @unavailable_servers && @unavailable_servers > 0 && (Time.now - @unavailable_timeout_time) > 10
       # The server streaming timed out!
       LOGGER.debug("Server streaming timed out with #{@unavailable_servers} servers remaining")
       LOGGER.debug('Calling ready now because server loading is taking a long time. Servers may be unavailable due to an outage, or your bot is on very large servers.')

       # Unset the unavailable server count so this doesn't get triggered again
       @unavailable_servers = 0

       notify_ready
     end

     case type
     when :READY
       # As READY may be called multiple times over a single process lifetime, we here need to reset the cache entirely
       # to prevent possible inconsistencies, like objects referencing old versions of other objects which have been
       # replaced.
       init_cache

       @profile = Profile.new(data['user'], self)

       # Initialize servers
       @servers = {}

       # Count unavailable servers
       @unavailable_servers = 0

       data['guilds'].each do |element|
         # Check for true specifically because unavailable=false indicates that a previously unavailable server has
         # come online
         if element['unavailable'].is_a? TrueClass
           @unavailable_servers += 1

           # Ignore any unavailable servers
           next
         end

         ensure_server(element)
       end

       # Add PM and group channels
       data['private_channels'].each do |element|
         channel = ensure_channel(element)
         if channel.pm?
           @pm_channels[channel.recipient.id] = channel
         else
           @channels[channel.id] = channel
         end
       end

       # Don't notify yet if there are unavailable servers because they need to get available before the bot truly has
       # all the data
       if @unavailable_servers.zero?
         # No unavailable servers - we're ready!
         notify_ready
       end

       @ready_time = Time.now
       @unavailable_timeout_time = Time.now
     when :GUILD_MEMBERS_CHUNK
       id = data['guild_id'].to_i
       server = server(id)
       server.process_chunk(data['members'])
     when :MESSAGE_CREATE
       
       ladder(data)
       
       
       if ignored?(data['author']['id'].to_i)
         debug("Ignored author with ID #{data['author']['id']}")
         return
       end

       if @ignore_bots && data['author']['bot']
         debug("Ignored Bot account with ID #{data['author']['id']}")
         return
       end

       # If create_message is overwritten with a method that returns the parsed message, use that instead, so we don't
       # parse the message twice (which is just thrown away performance)
       message = create_message(data)
       message = Message.new(data, self) unless message.is_a? Message

       return if message.from_bot? && !should_parse_self

       event = MessageEvent.new(message, self)
       raise_event(event)

       if message.mentions.any? { |user| user.id == @profile.id }
         event = MentionEvent.new(message, self)
         raise_event(event)
       end

       if message.channel.private?
         event = PrivateMessageEvent.new(message, self)
         raise_event(event)
       end
     when :MESSAGE_UPDATE
       update_message(data)

       message = Message.new(data, self)
       return if message.from_bot? && !should_parse_self

       unless message.author
         LOGGER.debug("Edited a message with nil author! Content: #{message.content.inspect}, channel: #{message.channel.inspect}")
         return
       end

       event = MessageEditEvent.new(message, self)
       raise_event(event)
     when :MESSAGE_DELETE
       delete_message(data)

       event = MessageDeleteEvent.new(data, self)
       raise_event(event)
     when :MESSAGE_DELETE_BULK
       debug("MESSAGE_DELETE_BULK will raise #{data['ids'].length} events")

       data['ids'].each do |single_id|
         # Form a data hash for a single ID so the methods get what they want
         single_data = {
           'id' => single_id,
           'channel_id' => data['channel_id']
         }

         # Raise as normal
         delete_message(single_data)

         event = MessageDeleteEvent.new(single_data, self)
         raise_event(event)
       end
     when :TYPING_START
       start_typing(data)

       begin
         event = TypingEvent.new(data, self)
         raise_event(event)
       rescue Discordrb::Errors::NoPermission
         debug 'Typing started in channel the bot has no access to, ignoring'
       end
     when :MESSAGE_REACTION_ADD
       add_message_reaction(data)

       return if profile.id == data['user_id'].to_i && !should_parse_self

       event = ReactionAddEvent.new(data, self)
       raise_event(event)
     when :MESSAGE_REACTION_REMOVE
       remove_message_reaction(data)

       return if profile.id == data['user_id'].to_i && !should_parse_self

       event = ReactionRemoveEvent.new(data, self)
       raise_event(event)
     when :MESSAGE_REACTION_REMOVE_ALL
       remove_all_message_reactions(data)

       event = ReactionRemoveAllEvent.new(data, self)
       raise_event(event)
     when :PRESENCE_UPDATE
       # Ignore friends list presences
       return unless data['guild_id']

       now_playing = data['game'].nil? ? nil : data['game']['name']
       presence_user = @users[data['user']['id'].to_i]
       played_before = presence_user.nil? ? nil : presence_user.game
       update_presence(data)

       event = if now_playing != played_before
                 PlayingEvent.new(data, self)
               else
                 PresenceEvent.new(data, self)
               end

       raise_event(event)
     when :VOICE_STATE_UPDATE
       old_channel_id = update_voice_state(data)

       event = VoiceStateUpdateEvent.new(data, old_channel_id, self)
       raise_event(event)
     when :VOICE_SERVER_UPDATE
       update_voice_server(data)

       # no event as this is irrelevant to users
     when :CHANNEL_CREATE
       create_channel(data)

       event = ChannelCreateEvent.new(data, self)
       raise_event(event)
     when :CHANNEL_UPDATE
       update_channel(data)

       event = ChannelUpdateEvent.new(data, self)
       raise_event(event)
     when :CHANNEL_DELETE
       delete_channel(data)

       event = ChannelDeleteEvent.new(data, self)
       raise_event(event)
     when :CHANNEL_RECIPIENT_ADD
       add_recipient(data)

       event = ChannelRecipientAddEvent.new(data, self)
       raise_event(event)
     when :CHANNEL_RECIPIENT_REMOVE
       remove_recipient(data)

       event = ChannelRecipientRemoveEvent.new(data, self)
       raise_event(event)
     when :GUILD_MEMBER_ADD
       add_guild_member(data)

       event = ServerMemberAddEvent.new(data, self)
       raise_event(event)
     when :GUILD_MEMBER_UPDATE
       update_guild_member(data)

       event = ServerMemberUpdateEvent.new(data, self)
       raise_event(event)
     when :GUILD_MEMBER_REMOVE
       delete_guild_member(data)

       event = ServerMemberDeleteEvent.new(data, self)
       raise_event(event)
     when :GUILD_BAN_ADD
       add_user_ban(data)

       event = UserBanEvent.new(data, self)
       raise_event(event)
     when :GUILD_BAN_REMOVE
       remove_user_ban(data)

       event = UserUnbanEvent.new(data, self)
       raise_event(event)
     when :GUILD_ROLE_UPDATE
       update_guild_role(data)

       event = ServerRoleUpdateEvent.new(data, self)
       raise_event(event)
     when :GUILD_ROLE_CREATE
       create_guild_role(data)

       event = ServerRoleCreateEvent.new(data, self)
       raise_event(event)
     when :GUILD_ROLE_DELETE
       delete_guild_role(data)

       event = ServerRoleDeleteEvent.new(data, self)
       raise_event(event)
     when :GUILD_CREATE
       create_guild(data)

       # Check for false specifically (no data means the server has never been unavailable)
       if data['unavailable'].is_a? FalseClass
         @unavailable_servers -= 1 if @unavailable_servers
         @unavailable_timeout_time = Time.now

         notify_ready if @unavailable_servers.zero?

         # Return here so the event doesn't get triggered
         return
       end

       event = ServerCreateEvent.new(data, self)
       raise_event(event)
     when :GUILD_UPDATE
       update_guild(data)

       event = ServerUpdateEvent.new(data, self)
       raise_event(event)
     when :GUILD_DELETE
       delete_guild(data)

       if data['unavailable'].is_a? TrueClass
         LOGGER.warn("Server #{data['id']} is unavailable due to an outage!")
         return # Don't raise an event
       end

       event = ServerDeleteEvent.new(data, self)
       raise_event(event)
     when :GUILD_EMOJIS_UPDATE
       server_id = data['guild_id'].to_i
       server = @servers[server_id]
       old_emoji_data = server.emoji.clone
       update_guild_emoji(data)
       new_emoji_data = server.emoji

       created_ids = new_emoji_data.keys - old_emoji_data.keys
       deleted_ids = old_emoji_data.keys - new_emoji_data.keys
       updated_ids = old_emoji_data.select do |k, v|
         new_emoji_data[k] && (v.name != new_emoji_data[k].name || v.roles != new_emoji_data[k].roles)
       end.keys

       event = ServerEmojiChangeEvent.new(server, data, self)
       raise_event(event)

       created_ids.each do |e|
         event = ServerEmojiCreateEvent.new(server, new_emoji_data[e], self)
         raise_event(event)
       end

       deleted_ids.each do |e|
         event = ServerEmojiDeleteEvent.new(server, old_emoji_data[e], self)
         raise_event(event)
       end

       updated_ids.each do |e|
         event = ServerEmojiUpdateEvent.new(server, old_emoji_data[e], new_emoji_data[e], self)
         raise_event(event)
       end
     when :WEBHOOKS_UPDATE
       event = WebhookUpdateEvent.new(data, self)
       raise_event(event)
     else
       # another event that we don't support yet
       debug "Event #{type} has been received but is unsupported. Raising UnknownEvent"

       event = UnknownEvent.new(type, data, self)
       raise_event(event)
     end

     # The existence of this array is checked before for performance reasons, since this has to be done for *every*
     # dispatch.
     if @event_handlers && @event_handlers[RawEvent]
       event = RawEvent.new(type, data, self)
       raise_event(event)
     end
   rescue Exception => e
     LOGGER.error('Gateway message error!')
     log_exception(e)
   end
 end
end
end



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
