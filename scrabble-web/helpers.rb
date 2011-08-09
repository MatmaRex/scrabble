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
		def cookie_expiration_time
			60 * 60 * 24 * 365 # 1 year
		end
		
		def get_logged_in_player gamename, game
			playerid, password = @cookies["game-#{gamename}-playerid"], @cookies["game-#{gamename}-password"]
			playerid = playerid[:value] if playerid.is_a? Hash
			password = password[:value] if password.is_a? Hash
			
			loggedinas = game.players.select{|pl| pl.id==playerid.to_i and pl.password==password}[0]
			loggedinas
		end
		
		# Should be pl/en/something similar, if the browser is at all sensible. Returns string.
		def get_lang_from_headers
			@env['HTTP_ACCEPT_LANGUAGE'].to_s[0, 2]
		end
		
		# This also sets the cookie if it's missing! Returns a symbol.
		def get_lang
			if @cookies['lang']
				# we have a cookie - do not set it at all, just read
				if @cookies['lang'].is_a?(Hash)
					cur_lang = @cookies['lang'][:value].to_sym
				else
					cur_lang = @cookies['lang'].to_sym
				end
			else
				# no cookie - set it, don't validate yet
				cur_lang = get_lang_from_headers
				@cookies['lang'] = {value: cur_lang, expires:(Time.now+cookie_expiration_time)}
				cur_lang = cur_lang.to_sym
			end
			
			# validate the language
			langs = %w[pl en].map(&:to_sym)
			cur_lang = (langs.include?(cur_lang) ? cur_lang : :en)
			
			return cur_lang
		end
		
		def loc str, target_lang=nil
			lang = target_lang || get_lang()
			if lang==:en
				str
			else
				warn "no #{lang} translation for '#{str}'" if !SCRABBLE_TRANSLATIONS[lang][str]
				SCRABBLE_TRANSLATIONS[lang][str] || str
			end
		end
	end
end
