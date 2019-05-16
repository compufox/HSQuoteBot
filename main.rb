require 'elephrame'
require 'sqlite3'

# init out constants
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


# search for a certain name or group
def get_specific_quote search
  character = ''
  link = ''
  title = ''
  
  SpecificStatement.execute(search, search).collect.to_a.sample.collect do |quote|
    character = quote['name']
    link = "https://homestuck.com#{quote['link']}"
    title = quote['title']
    color = ColorRegex.match(quote['text'])
    color = color.nil? ? 'ffffff' : color['color']
    quote = "[hs][colorhex=#{color}]#{quote['text'].gsub(ColorRegex, '')}[/colorhex][/hs]"
  end.join("\n")
  { text: quote, character: character, link: link, title: title }
end


# get a generic random quote
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

# parse post and get name or group and
#  reply with a random quote from that group
#  or character
Bot.on_reply do |bot, post|
  next # until i sort out whats going on with regexing the post
  if post.content.start_with?('!help')
    bot.reply(HelpMsg,
              spoiler: 'bot help post.content')
  else
    hit = NameRegex.match(post.content) || CategoryRegex.match(post.content)
    
    if hit.nil?
      bot.reply('I didn\'t recognize who that was. Reply with !help to get a list of names')
    else
      capture = hit.named_captures.keys.first
      quote = get_specific_quote(hit[capture])
      bot.reply_with_mentions("#{quote[:text]}\n\n#{quote[:link]}",
                              spoiler: quote[:title])
    end
  end
end

# get a quote and post it
Bot.run do |bot|
  quote = get_random_quote()
  bot.post("#{quote[:text]}\n\n#{quote[:link]}",
           spoiler: quote[:title])
end
