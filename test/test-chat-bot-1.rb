# @bot = ::Discordrb::Bot.new token: ENV['TEST_BOT_TOKEN']


# bot.message(with_text: 'pipeline:') do |event| # message must only cntain the text
#
#
#   bot.message(content: '!pipeline gbot-id-capture') do |event| # message content must exactly match the content: value
#         event.respond("Type start to begin")
#         event.user.await(:start) do |start_event| # awaits any input by the user (or any user?)
#           event.respond('gbot: get-id')