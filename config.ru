$production = true
$heroku = !!ENV['DATABASE_URL']

require './scrabble-web.rb'
run ScrabbleWeb
