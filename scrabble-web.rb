# coding: utf-8

require './scrabble'

# this is a nasty fix. some versions of Markaby want to undef these methods, 
# and some versions of Builder do not define them,
# thus causing an exception. 
gem 'builder', '= 2.1.2'
require 'builder'
class Builder::BlankSlate
	unless method_defined? :to_s; def to_s; end; end
	unless method_defined? :inspect; def inspect; end; end
	unless method_defined? :==; def ==; end; end
end

require 'json'
require 'camping'
require 'pg' if $heroku


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


Camping.goes :ScrabbleWeb

module ScrabbleWeb
	module Helpers
		def get_logged_in_player gamename, game
			playerid, password = @cookies["game-#{gamename}-playerid"].to_i, @cookies["game-#{gamename}-password"]
			loggedinas = game.players.select{|pl| pl.id==playerid and pl.password==password}[0]
			loggedinas
		end
	end
	
	use Rack::Static, urls:['/static']
	module Controllers
		class Favicon < R '/favicon.ico'; def get; @headers['content-type']='image/vnd.microsoft.icon'; File.binread './favicon.ico'; end; end
		
		class Index
			def get
				if $heroku
					conn = get_conn()
					
					@gamelist = []
					res = conn.exec("SELECT name FROM games")
					res.each{|row| @gamelist << row['name'] }
				else
					@gamelist = Dir.entries('games').select{|a| a!='.' and a!='..'}.map{|a| a.sub(/-game\Z/, '')}
				end
				
				render :home
			rescue
				[$!.to_s, $!.backtrace].flatten.map{|a| a.force_encoding('cp1252')}.join "<br>"
			end
		end
		
		class NewGame < R '/new!'
			def post
				gamename = @request['gamename']
				playercount = @request['players'].to_i
				playernames = [ @request['player0'], @request['player1'], @request['player2'], @request['player3'] ]
				whoisadmin = ((@request['whoisadmin']!='' ? @request['whoisadmin'] : 1).to_i - 1)
				mode = (@request['mode'] && @request['mode']!='' ? @request['mode'].to_sym : :scrabble)
				
				return 'Players?' unless (1..4).include? playercount
				return 'Admin?' unless (0...playercount).include? whoisadmin
				
				if gamename =~ /\A[a-zA-Z0-9_-]+\Z/
					if !game_exist? gamename
						game = Scrabble::Game.new playercount, playernames, whoisadmin, mode
						@cookies["game-#{gamename}-playerid"] = whoisadmin
						@cookies["game-#{gamename}-password"] = game.players[whoisadmin].password
						
						put_game gamename, game
						
						redirect "/#{@request['gamename']}"
					else
						return "Game '#{gamename}' already exists."
					end
				else
					return 'Only ASCII letters, numbers, underscore and hyphen (a-z, A-Z, 0-9, _, -) allowed in game names.'
				end
			rescue
				[$!.to_s, $!.backtrace].flatten.map{|a| a.force_encoding('cp1252')}.join "<br>"
			end
		end
		
		class GameMicro < R '/micro!/([a-zA-Z0-9_-]+)'
			def get gamename
				@gamename = gamename
				
				if !game_exist? @gamename
					return ''
				else
					@game = get_game @gamename
				end
				
				if @game.over? and !@game.finished
					res = @game.do_endgame_calculations
					put_game @gamename, @game if res
				end
				
				@asker_hist_len = @request['hist_len'].to_i
				if @asker_hist_len == @game.history.length
					# nothing to update
					return ''
				else
					@loggedinas = get_logged_in_player @gamename, @game
					
					board = @game.board.board
					hsh = {}
					hsh['updateable'] = render(:_updateable).to_s
					hsh['hist_len'] = @game.history.length
					hsh['over'] = @game.over?
					
					board.each_index do |row|
						board[row].each_index do |col|
							if board[row][col]
								id = "#{row}-#{col}"
								hsh[id] = (board[row][col]=='?' ? @game.board.blank_replac[ [row, col] ].downcase_pl : board[row][col])
							end
						end
					end
					
					@headers['content-type']='text/javascript'
					return "scrabble_callback(#{hsh.to_json})"
				end
			end
		end
		
		class GetBlank < R '/blank!/([a-zA-Z0-9_-]+)'
			def post gamename
				@game = get_game gamename
				@loggedinas = get_logged_in_player gamename, @game
				
				
				return 'Not your turn.' if @loggedinas != @game.players[@game.whoseturn]
				return 'Game already over.' if @game.over?
				
				
				row, col = @request['loc'].match(/\A([a-z]+)([0-9]+)\z/i){ [([*'a'..'z'].index $1.downcase), ($2.to_i - 1)] }
				return 'Wrong input format?' if !row or !col
				
				return 'Not a blank here.' if @game.board.board[row][col] != '?'
				replace_with = @game.board.blank_replac[ [row, col] ].upcase_pl
				
				at = @loggedinas.letters.index replace_with
				return "You don't have this letter." unless at
				
				# all is fine - do the job.
				@game.board.board[row][col] = replace_with
				@loggedinas.letters[at] = '?'
				# don't change @game.board.blank_replac - it's used to update everybody's board
				
				put_game gamename, @game
				
				redirect "/#{gamename}"
			end
		end
		
		class Game < R '/([a-zA-Z0-9_-]+)'
			def common
				if !game_exist? @gamename
					return 'No such game.'
				else
					@game = get_game @gamename
				end
				
				@pagetitle = @gamename
				
				@loggedinas = get_logged_in_player @gamename, @game
				
				return nil
			end
			
			def get gamename
				@gamename = gamename
				err = common()
				return err if err
				
				
				if @game.over? and !@game.finished
					res = @game.do_endgame_calculations
					put_game @gamename, @game if res
				end
				
				
				render :game
			rescue
				[$!.to_s, $!.backtrace].flatten.map{|a| a.force_encoding('cp1252')}.join "<br>"
			end
			
			def post gamename
				@gamename = gamename
				err = common()
				return err if err
				
				return 'Not your turn.' if @loggedinas != @game.players[@game.whoseturn]
				return 'Game already over.' if @game.over?
				
				
				if @request['mode'] == 'OK'
					letts = []
					
					@request.params.each_pair do |id, lett|
						if id =~ /^\d+-\d+$/
							row, col = id.split('-').map(&:to_i)
							
							if lett and lett!='' and @game.board[row][col]==nil
								letts << [col, row, lett]
							end
						end
					end
					
					blank_replac = (@request['blank_replac']||'').upcase_pl.split('').select{|l| @game.board.letters_to_points.include?(l) and l!='?'}
					
					return 'You did nothing?' if letts.empty?
					
					begin
						@game.do_move letts, blank_replac, @loggedinas.id
					rescue Scrabble::WordError => e
						return 'Incorrect move.' + '<br>' + e.message.encode('utf-8') + get(@gamename).to_s.encode('utf-8')
					end
				
				elsif @request['mode'] == 'Pas/Wymiana'
					ch = (@request['change']||'').upcase_pl.split('').select{|l| @game.board.letters_to_points.include?(l) and l!='?'}
					
					@game.do_pass_or_change ch, @loggedinas.id
				end
				
				put_game @gamename, @game
				
				redirect "/#{@gamename}"
				
			rescue
				[$!.to_s, $!.backtrace].flatten.map{|a| a.force_encoding('cp1252')}.join "<br>"
			end
		end
		
		class JoinGame < R '/join!'
			def post
				@gamename, @password = @request['game'], @request['password']
				
				if !game_exist? @gamename
					return 'No such game.'
				else
					@game = get_game @gamename
				end
				
				as = @game.players.select{|pl| pl.password==@password}[0]
				
				if as
					@cookies["game-#{@gamename}-playerid"] = @game.players.index as
					@cookies["game-#{@gamename}-password"] = @password
					redirect "/#{@gamename}"
				else
					return 'Wrong password.'
				end
			rescue
				[$!.to_s, $!.backtrace].flatten.map{|a| a.force_encoding('cp1252')}.join "<br>"
			end
		end
	end
	
	module Views
		# Mab.set(:indent, 2) if !$production
		
		def layout
			html do
				head do
					title(@pagetitle ? "#{@pagetitle} - Scrabble" : "Scrabble")
					link rel:'stylesheet', type:'text/css', href:'/static/style.css'
					script '', type:'text/javascript', src:'/static/mintAjax.js'
					script '', type:'text/javascript', src:'/static/script.js'
				end
				body :class=>(@game.board.base_name rescue '') do
					yield
				end
			end
		end
		
		def home
			p 'Sup.'
			p 'Lista gier:'
			ul do
				@gamelist.each{|game| li{a game, href:"/#{game}"} }
			end
			p 'Utwórz nową:'
			form.create! method:'post', action:'/new!' do
				text 'Nazwa gry: '; input.gamename!; br
				text 'Liczba graczy (1-4): '; input.players!; br
				text 'Nicki kolejnych graczy (opcj.): '
				(0..3).each do |i|
					input name:"player#{i}"; text ' '
				end; br
				text 'Chcę być graczem numer: (1-4) '; input.whoisadmin!; br
				
				text 'Typ gry: ';
				label{ input type:'radio', name:'mode', value:'scrabble', checked:'checked'; text ' Scrabble' }
				label{ input type:'radio', name:'mode', value:'scrabble21'; text ' Scrabble21 (Super Scrabble)' }
				label{ input type:'radio', name:'mode', value:'literaki'; text ' Literaki' }
				br
				
				input type:'submit'
			end
		end
		
		def _board
			board = @game.board.board
			
			height = board.length
			width  = board[0].length
			
			div.board! do
				span.boardloc ''
				(1..width).each do |i|
					span.boardloc i.to_s
				end
				
				board.each_index do |row|
					span.boardloc [*'A'..'Z'][row]
					
					board[row].each_index do |col|
						id = "#{row}-#{col}"
						
						opts = {
							:class=>(@game.board.boardtpl[row][col]).to_s,
							id:id, name:id,
							size:1, maxlength:1
						}
						if board[row][col]
							opts.merge!(readonly: 'readonly')
							opts.merge!(value: (board[row][col]=='?' ? @game.board.blank_replac[ [row, col] ].downcase_pl : board[row][col]))
							opts[:class] += ' disab'
						else
							opts[:class] += ' enab'
						end
						
						input opts
					end
					br
				end
			end
		end
		
		def _players
			div.players! do
				@game.players.each do |pl|
					theclass = [
						'player',
						(@loggedinas==pl ? 'you' : ''),
						(@game.is_winner?(pl) ? 'winner' : '')
					].join ' '
					
					div 'class' => theclass do
						if pl.id == @game.whoseturn and !@game.over?
							img.currentimg src:'/static/arrow.gif'
						end
						
						p.playername pl.name
						
						p{b 'Admin gry'} if pl.admin
						
						p "Hasło do dołączenia: #{pl.password}" if @loggedinas and @loggedinas.admin
						
						p "Punkty: #{pl.points}"
						
						if @loggedinas == pl or @game.over?
							p "Litery: #{pl.letters.join ' '}"
						else
							p "Liter: #{pl.letters.length}"
						end
					end
				end
			end
		end
		
		def _gameinfo
			if @game.over?
				p.whoseturn! "Gra zakończona!"
			else
				p.whoseturn! "Teraz: #{@game.players[@game.whoseturn].name}"
			end
			
			p.letterleft! "Zostało: #{@game.board.letter_queue.length} liter"
		end
		
		def _history
			table.history! do
				tr do
					@game.players.each do |pl|
						th pl.name
					end
				end
				
				@game.history.each_slice(@game.players.length) do |slice|
					tr do
						slice.each do |entry|
							td do
								if entry.mode == :word
									"#{entry.score} punktów: #{entry.words.map{|w| w.letters.join ''}.join ', '}"
								elsif entry.mode == :pass
									"Pas."
								elsif entry.mode == :change
									"Wymienił(a) #{entry.changed_count} liter."
								elsif entry.mode == :adj
									"#{entry.score>0 ? '+' : '-'}#{entry.score.abs}"
								end
							end
						end
					end
				end
			end
		rescue
			text ''
		end
		
		def _getblank
			if @loggedinas and !@game.over?
				if @game.board.board.flatten.include? '?'
					form.getblank! method:'post', action:R(GetBlank, @gamename) do
						text 'Podmień blanka - podaj jego pozycję: (np. B12) '
						input.loc!
						input type:'submit'
					end
				end
			end
		end
		
		def _updateable
			_getblank
			_gameinfo
			_players
			_history
		end
		
		def game
			form method:'post', action:R(Game, @gamename) do
				_board
				br
				
				if @loggedinas
					div.rack! do
						text 'Stojak: '
						div.rackdropzone! do
							@loggedinas.letters.each_with_index do |let, i|
								input.rackletter id:"letter#{i}", readonly:'readonly', value:let
							end
						end
					end
					
					script "dropzone_setup(#{@loggedinas.letters.length})", type:'text/javascript'
				end
				
				if @loggedinas and !@game.over?
					div.controls! do
						if @loggedinas.letters.include? '?'
							br
							text 'Jeśli używasz blanka, wpisz tu, jaką literą chcesz go zastąpić: '
							input.blank_replac!
							if @loggedinas.letters.count('?') > 1
								text ' (jeśli używasz więcej niż jednego, wpisz dwie litery; najpierw podaj literę dla tego blanka, który jest bliżej lewej strony lub góry planszy)'
							end
						end
						
						br
						input name:'mode', type:'submit', value:'OK'
						text ' '
						input type:'reset', value:'Od nowa'
						
						br
						input.change!
						text ' '
						input name:'mode', type:'submit', value:'Pas/Wymiana' 
					end
				end
			end
			
			
			
			div.updateable! do
				_updateable
			end
			
			p.legend! do
				hsh = @game.board.letters_to_points
				order = hsh.keys.sort_by_pl
				
				b 'Legenda: '
				text order.map{|let| "#{let}=#{hsh[let]}"}.join ', '
			end
			p.legend2! do
				hsh = @game.board.letter_freq
				order = hsh.keys.sort_by_pl
				
				b 'Liczba płytek: '
				text order.map{|let| "#{let}x#{hsh[let]}"}.join ', '
			end
			
			if !@loggedinas and !@game.over?
				form.joingame! method:'post', action:R(JoinGame) do
					input.game! type:'hidden', value:@gamename
					text 'Dołącz go gry - hasło: '; input.password!
					input type:'submit'
				end
			end
			
			js = [
				"gamename = '#{@gamename}'",
				"hist_len = #{@game.history.length}",
				"document.body.addEventListener('keypress', arrow_listener, true)",
				!@game.over? ? "setInterval(scrabble_check, #{$production ? 3000 : 15000})" : ''
			]
			
			script js.join('; '), type:'text/javascript'
		end
	end
end

