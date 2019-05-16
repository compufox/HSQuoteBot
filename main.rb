require 'elephrame'
require 'sqlite3'

Database = SQLite3::Database.new('quotes.db')
Bot = Elephrame::Bots::PeriodInteract.new '2h'
MaxID = Database.execute('select max(group_id) from quotes').first.first
Database.results_as_hash = true
RandomStatement = Database.prepare('select text,
                                    character_name as name,
                                    page_title as title,
                                    page_link as link
                                    from quotes
                                    where group_id = ?')
SpecificStatement = Database.prepare('select text,
                                      character_name as name,
                                      page_title as title,
                                      page_link as link
                                      from quotes
                                      where (character_name like ? or
                                             character_category like ?)')
ColorRegex = /<span style="color: #(?<color>.{6})">|<\/span>/
Names = Database.execute('select distinct(character_name) as name
                          from quotes').collect {|n| n['name']}
Categories = Database.execute('select distinct(character_category) as category 
                               from quotes').collect {|c| c['category']}
NameRegex = /(?<name>#{Names.join('|')})/i
CategoryRegex = /(?<category>#{Categories.join('|')})/i
HelpMsg = "I recognize these names: #{Names.join(', ')}\nAnd these categories: #{Categories.join(', ')}"


def get_specific_quote search
  character = ''
  link = ''
  title = ''
  quote = SpecificStatement.execute(search, search).sample.collect do |quote|
    character = quote['name']
    link = "https://homestuck.com#{quote['link']}"
    title = quote['title']
    color = ColorRegex.match(quote['text'])
    color = color.nil? ? 'ffffff' : color['color']
    "[hs][colorhex=#{color}]#{quote['text'].gsub(ColorRegex, '')}[/colorhex][/hs]"
  end.join("\n")
  { text: quote, character: character, link: link, title: title }
end


def get_random_quote
  character = ''
  link = ''
  title = ''
  quote = Statement.execute(rand MaxID).collect do |quote|
    character = quote['name']
    link = "https://homestuck.com#{quote['link']}"
    title = quote['title']
    color = ColorRegex.match(quote['text'])
    color = color.nil? ? 'ffffff' : color['color']
    "[hs][colorhex=#{color}]#{quote['text'].gsub(ColorRegex, '')}[/colorhex][/hs]"
  end.join("\n")

  { text: quote, character: character, link: link, title: title }
end

Bot.on_reply do |bot, post|
  # parse post and get name or group and
  #  reply with a random quote from that group
  #  or character

  post = post.content
  if post.start_with?('!help')
    bot.reply(HelpMsg,
              spoiler: 'bot help post')
  else
    hit = NameRegex.match(post) || CategoryRegex.match(post)

    if hit.nil?
      bot.reply('I didn\'t recognize who that was. Reply with !help to get a list of names')
    else
      quote = get_specific_quote(hit.named_captures.first.value)
      bot.reply_with_mentions("#{quote[:text]}\n\n#{quote[:link]}",
                              spoiler: quote[:title])
    end
  end
end

Bot.run do |bot|
  quote = get_random_quote()
  bot.post("#{quote[:text]}\n\n#{quote[:link]}",
           spoiler: quote[:title])
end
