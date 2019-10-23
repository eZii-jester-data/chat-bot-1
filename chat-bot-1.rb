require 'ladder'
require 'discordrb'

class FalseClass
  def false?
    self == false
  end
end
class TrueClass
  def false?
    self == false
  end
end


class GBotResponseNotCapture < Exception
end

module EZIIDiscordIntegration
  
  TEST_COMMAND_STRING = "5 results for te123§§st"
  MESSAGE = "gbot: #{TEST_COMMAND_STRING} | filter by curl response time | top 1"
  
  
  VIRTUAL_EXCEPTION = {}



  USER_ID_HOLDER = {gbot_id: nil}
  FIRST_GBOT_MESSAGE_HOLDER = {first_gbot_message_id: nil}
    

  ERR_ID_0 = "search string for gbot is not a string"# ,
  ERR_ID_1 = "respoonse not delivered within 1 second"# ,
  ERR_ID_2 = "Gbot discord user id was not configured, start the assignment after bot restart by '!pipeline gbot-id-capture"# ,
  ERR_ID_3 = "Gbot didn't respond within timeframe"# ,
  ERR_ID_4 = "Gbot answered more than once within timeframe (this bot must run in a channel where only this bot is allowed to write messages to gbot)"# ,
  ERR_ID_5 = "ID of all following gbot messages must not equal the id of the first gbot message"
  ERR_ID_6 = "ID of first gbot message received by this program must not be nil"
  ERR_ID_7 = "DISCORD_MESSAGES must be synced globally"
  ERR_ID_8 = "Curl not working dum dum"

  

  def self.monkeypatching
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


  def self.split_into_pipe_parts(message: '', pipe_unicode_symbol: '|')
    message.split('|')
  end

  

  class PipelineDiscordBot
    CURL_RESPONSES_HOLDER = {}
    
    attr_reader :bot
  
  
    def initialize
      @bot = ::Discordrb::Bot.new token: ENV['BOT_TOKEN']
      
      self.add_pipeline_command
      self.add_gbot_id_fetch_command
    end
  
    def get_gbot_message(query, event, callback)
      command = GbotCommandForBot2Bot.new(query, event)
      capture = GbotCommandResponseCapture.new(command)
  
      capture.command.send do  
        capture.pump_once do
          if !capture.response.nil? && extract_urls_from_gbot_response(capture.response).any?
            callback.call(capture.response) 
          end
        end
      end
    end
  
    def use(*args)
      yield
    end
    
    def where_the_use_would_fail(*args)
      yield
    end
    
    def §(*args)
      yield if block_given?
    end
    
    ESSENTIAL_DECLARATINO_OF_LOCAL_VARIABLE = [self, 0]
  
    def add_pipeline_command
      bot.message(with_text: 'pipeline:') do |event|
          
        if USER_ID_HOLDER[:gbot_id].nil?
          event.respond("Please first initialize via !pipeline gbot-id-capture")

        else
          
          event.user.await(:pipeline_definition) do |pipeline_definition_message_event|                     
                        
          
            user_message = pipeline_definition_message_event.message.content
            
          pipe_parts = EZIIDiscordIntegration.split_into_pipe_parts(message: MESSAGE.gsub('te123§§st', user_message), pipe_unicode_symbol: '|')

          event.respond pipe_parts.inspect

          pipeline = Pipeline.new
          pipe_parts.each do |pipe_part| pipeline.add(pipe_part) end


          
          pipeline.run { |message, left_commands_count, new_output_value_callback, last_output_value_callback|
    
 
    
            event.respond("Commands to be run after this one: #{left_commands_count}, now running:")

            thread = lambda { |est| est.call }
                      if message =~ /gbot/
                            get_gbot_message(
                              message.gsub('gbot:', ''), 
                              event, 
                              ->(response_message) do
                                 new_output_value_callback.call(response_message)
                               end)
                  
                    
                     end 
                
                
                      if message =~ /curl/
                        CURL_RESPONSES_HOLDER[0] = lambda do |&block|
                          last_output_value_callback.call do |value|
                              block.call(prepare_curl_responses(value))
                            end
                          end
                      end
                  
                    
                   if message =~ /top/
                     CURL_RESPONSES_HOLDER[0].call do |value|
                        event.respond(value.wait_for_finish.winner)
                      end  
                    end
                  
          }
        end
        
        end
      end
    end
    
    require_relative './lib/ezii_curl_manager.rb'
    def prepare_curl_responses(gbot_message)
      cm = CurlManager.new(     extract_urls_from_gbot_response(    gbot_message    )       )
      
      cm.start_calls_in_background
      
      
      return cm
    end
    
    
    def extract_urls_from_gbot_response(gbot_message)
      return gbot_message.scan(/<([^>]*)>/)
    end
  
  
    def add_gbot_id_fetch_command
      bot.message(content: '!pipeline gbot-id-capture') do |event|
        event.respond("Type start to begin")
        event.user.await(:start) do |start_event|
          event.respond('gbot: get-id')
   
          ladder { |data|
              if(data['author']['username'] == 'GBot')
                USER_ID_HOLDER[:gbot_id] ||= data['author']['id']
                FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id] ||= data['id']
                
                event.respond('Google Bot Discord ID is ' + USER_ID_HOLDER[:gbot_id].inspect)
              end
          }
        end
      end
    end
  end


  class Pipeline
    attr_accessor :block
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
        last_item = yield(@queue.shift, @queue.size, new_output_value_callback, last_output_value_callback)
      end
    end
  
  
    def new_output_value_callback
      return Proc.new do |new_value|      
        self.block.call(new_value)
      end
    end
  
    def last_output_value_callback
      return Proc.new do |&block|
        self.block = block
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
  
  module Pipeline::ExpectResponseWithin
    module ClassMethods
      def timeframe_for_response=(timeframe_in_seconds)
        @timeframe_in_seconds = timeframe_in_seconds
      end
    
      def timeframe_for_response
        @timeframe_in_seconds
      end
    end
  end
  
  
  
  class GbotCommandResponseCapture
    attr_accessor :command
    def initialize(command)
      @command = command
    end
  
    extend Pipeline::ExpectResponseWithin::ClassMethods

    @user_id_of_message_to_be_captured = USER_ID_HOLDER
    self.timeframe_for_response = 200 # Second
  
  
    def ALL_FALSE(*args)
      args.all?(&:false?)
    end
    
    def ALL_FALSE_INSPECT(*args)
      args.each_slice(2).map { |boolean, explanation|
        "#{explanation}: #{boolean}"
      }.join(' <> ')
    end
    
    
    def pump_once(&block)
      count = 0
      self.pump do
        @stop_ladder = true if count > 0 
        
        
        if @stop_ladder
          ladder(stop: @ladder_1)
        else  
          block.call
          count += 1
        end
      end
    end
    
    def pump(&block)
      fail ERR_ID_2 if self.class.instance_variable_get(:@user_id_of_message_to_be_captured)[:gbot_id].nil?
    
    
      gbot_id = self.class.instance_variable_get(:@user_id_of_message_to_be_captured)[:gbot_id]
    
      message = nil
      messages_by_gbot_in_timeframe = 0
      @ladder_1 = ladder do |message_data|
 
        puts message_data.inspect
    
        puts ALL_FALSE_INSPECT(
          message_data.nil?, "message_data.nil?",
          FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id].nil?, "FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id].nil?",
          message_data['id'] == FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id], "message_data['id'] == FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id]"
        )
          
          
        if ALL_FALSE(message_data.nil?, FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id].nil?, message_data['id'] == FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id])
            fail ERR_ID_7 if message_data.nil?
            fail ERR_ID_6 if FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id].nil?
            fail ERR_ID_5 if message_data['id'] == FIRST_GBOT_MESSAGE_HOLDER[:first_gbot_message_id] # or fail ERR_ID_5
    
          if message_data['author']['id'] == gbot_id
            messages_by_gbot_in_timeframe += 1
      
            message = message_data['content']
          end
    
    
          fail ERR_ID_3 if message.nil?
          # next if message.nil?
          fail ERR_ID_4 if messages_by_gbot_in_timeframe > 1
    
          @message = message
          
          puts "TEST TEST"
      
          block.call
        end
      end
    end
  
    def response
      @message
    end
  end

  class GbotCommandForBot2Bot
    def initialize(text, event)
      @text = text
      @event = event
    end

    def to_discord_message
      "gbot: #{@text.to_s}"
    end
  
    def send
      @event.respond(self.to_discord_message)
    
    
      yield
    end
  end
end



  ladder {}

EZIIDiscordIntegration::PipelineDiscordBot.new.bot.run
