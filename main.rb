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
                                      where group_id = (
                                        select group_id from quotes
                                          where (lower(character_name) = lower(?) or
                                                 lower(character_category) = lower(?))
                                        order by random() limit 1
                                      )')
ColorRegex = /<span style="color: #(?<color>.{6})">|<\/span>/
Names = Database.execute('select distinct(character_name) as name
                          from quotes')
          .select  {|n| !n['name'].empty?}
          .collect {|n| n['name']}
Categories = Database.execute('select distinct(character_category) as category 
                               from quotes')
               .select  {|c| !c['category'].empty?}
               .collect {|c| c['category']}
NameRegex = /(?<name>#{Names.map{|n| Regexp.quote(n) unless n.nil?}.join('|')})/i
CategoryRegex = /(?<category>#{Categories.map{|c| Regexp.quote(c) unless c.nil?}.join('|')})/i
HelpMsg = "I recognize these names: #{Names.join(', ')}\nAnd these categories: #{Categories.join(', ')}"


# get a quote from our database
#  if the search is nil we get a random quote,
#  otherwise we search first and then get a random one from the results
def get_quote search = nil
  character = ''
  link = ''
  title = ''

  rows = search.nil? ?
           RandomStatement.execute(rand MaxID) :
           SpecificStatement.execute(search, search)
  
  quote = rows.collect do |quote|
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
  if post.content.gsub(/@\w+/, '').strip.start_with?('!help')
    bot.reply(HelpMsg, spoiler: 'bot help')
  else
    hit = NameRegex.match(post.content) || CategoryRegex.match(post.content)
    
    if hit.nil?
      bot.reply('I didn\'t recognize who that was. Reply with !help to get a list of names')
    else
      capture = hit.named_captures.keys.first
      quote = get_quote(hit[capture])
      bot.reply_with_mentions("#{quote[:text]}\n\n#{quote[:link]}",
                              spoiler: quote[:title])
    end
  end
end

# get a quote and post it
Bot.run do |bot|
  quote = get_quote
  bot.post("#{quote[:text]}\n\n#{quote[:link]}",
           spoiler: quote[:title])
end
