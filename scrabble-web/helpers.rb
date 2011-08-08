# coding: utf-8

def get_conn
	_, user, pass, host, db = *ENV['DATABASE_URL'].match(%r|\Apostgres://(.+?):(.+?)@(.+?)/(.+)\Z|)
	conn = PGconn.new host, 5432, '', '', db, user, pass
	
	# create table if it doesn't exist
	begin
		conn.exec 'CREATE TABLE games (name text, base64_marshal text)'
	rescue Exception
	end
	
	conn
end

def fname_for gamename
	'./games/' + "#{gamename}-game"
end


def get_list_of_games
	if $heroku
		conn = get_conn()
		
		list = []
		res = conn.exec("SELECT name FROM games")
		res.each{|row| list << row['name'] }
		conn.finish
	else
		list = Dir.entries('games').select{|a| a!='.' and a!='..'}.map{|a| a.sub(/-game\Z/, '')}
	end
	
	list
end


def get_game gamename
	if $heroku
		conn = get_conn()
		game = conn.exec("SELECT base64_marshal FROM games WHERE name LIKE '#{gamename}'")[0]['base64_marshal']
		conn.finish
		game = Marshal.load Base64.decode64 game
		game
	else
		game = Marshal.load File.binread fname_for gamename
		game.players.map!{|pl| (pl.is_a?(Scrabble::Player) ? pl : Scrabble::Player.new(pl) )} # workaround for superold games
		game
	end
end

def put_game gamename, game
	if $heroku
		updating = (game_exist? gamename)
		
		conn = get_conn()
		data = Base64.encode64 Marshal.dump game
		
		if updating
			conn.exec "UPDATE games SET base64_marshal='#{data}' WHERE name LIKE '#{gamename}'"
		else
			conn.exec "INSERT INTO games VALUES ('#{gamename}', '#{data}')"
		end
		
		conn.finish
	else
		File.open(fname_for(gamename), 'wb'){|f| f.write Marshal.dump game}
	end
end

def delete_game gamename
	if $heroku
		conn = get_conn()
		game = conn.exec("DELETE FROM games WHERE name LIKE '#{gamename}'")
		conn.finish
	else
		File.delete fname_for gamename
	end
end

def game_exist? gamename
	if $heroku
		conn = get_conn()
		exist = (conn.exec("SELECT name FROM games WHERE name LIKE '#{gamename}'").getvalue(0,0) rescue false)
		conn.finish
		!!exist
	else
		File.exist? fname_for gamename
	end
end


module ScrabbleWeb
	module Helpers
		def get_logged_in_player gamename, game
			playerid, password = @cookies["game-#{gamename}-playerid"].to_i, @cookies["game-#{gamename}-password"]
			loggedinas = game.players.select{|pl| pl.id==playerid and pl.password==password}[0]
			loggedinas
		end
	end
end
