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


def fname_for gamename
	'./games/' + "#{gamename}-game"
end

def get_game gamename
	Marshal.load File.binread fname_for gamename
end

def put_game gamename, game
	File.open(fname_for(gamename), 'wb'){|f| f.write Marshal.dump game}
end

def game_exist? gamename
	File.exist? fname_for gamename
end


Camping.goes :ScrabbleWeb

module ScrabbleWeb
	module Controllers
		class StyleCss < R '/style.css'
			def get
				@headers['Content-Type']='text/css'
				File.read 'static/style.css'
			end
		end
		class ScriptJs < R '/script.js'
			def get
				@headers['Content-Type']='text/javascript'
				File.read 'static/script.js'
			end
		end
		class ArrowGif < R '/arrow.gif'
			def get
				@headers['Content-Type']='image/gif'
				File.binread 'static/arrow.gif'
			end
		end
		class HilitGif < R '/hilit.gif'
			def get
				@headers['Content-Type']='image/gif'
				File.binread 'static/hilit.gif'
			end
		end
		
		class Index
			def get
				@gamelist = Dir.entries('games').select{|a| a!='.' and a!='..'}.map{|a| a.sub(/-game\Z/, '')}
				render :home
			end
		end
		
		class NewGame < R '/new!'
			def post
				gamename = @request['gamename']
				playercount = @request['players'].to_i
				playernames = [ @request['player0'], @request['player1'], @request['player2'], @request['player3'] ]
				
				return 'Players?' unless (2..4).include? playercount
				
				if gamename =~ /\A[a-zA-Z0-9_-]+\Z/
					if !game_exist? gamename
						game = Scrabble::Game.new playercount, playernames
						@cookies["game-#{gamename}-playerid"] = 0
						@cookies["game-#{gamename}-password"] = game.players[0][:password]
						
						put_game gamename, game
						
						redirect "/#{@request['gamename']}"
					else
						return "Game '#{gamename}' already exists."
					end
				else
					return 'Only ASCII letters, numbers, underscore and hyphen  (a-z, A-Z, 0-9, _, -) allowed in game names.' 
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
					@game.finished = true
					
					finished = @game.players.select{|pl| pl[:letters].empty? }[0]
					adj = @game.players.map{|pl| pl[:letters].map{|lt| @game.board.letters_to_points[lt]}.inject(0, &:+) * -1  }
					
					adj[ finished[:id] ] = (adj.inject &:+) * -1 if finished
					
					@game.players.each_with_index do |pl, i|
						pl[:points] += adj[i]
					end
					
					
					adj.rotate! @game.whoseturn
					@game.history += adj.map{|pt| Scrabble::HistoryEntry.new(:adj, nil, nil, pt)}
				
					# save changes
					put_game @gamename, @game
				end
				
				@asker_hist_len = @request['hist_len'].to_i
				if @asker_hist_len == @game.history.length
					# nothing to update
					return ''
				else
					playerid, password = @cookies["game-#{@gamename}-playerid"].to_i, @cookies["game-#{@gamename}-password"]
					@loggedinas = @game.players.select.with_index{|pl, id| id==playerid and pl[:password]==password}[0]
					
					
					board = @game.board.board
					hsh = {}
					hsh['updateable'] = render(:_gameinfo).to_s + render(:_players).to_s + render(:_history).to_s
					hsh['hist_len'] = @game.history.length
					hsh['over'] = @game.over?
					
					board.each_index do |row|
						board[row].each_index do |col|
							id = "#{row}-#{col}"
							hsh[id] = (board[row][col]=='?' ? @game.board.blank_replac[ [row, col] ].downcase_pl : board[row][col]) if board[row][col]
						end
					end
					
					@headers['content-type']='text/javascript'
					return "scrabble_callback(#{hsh.to_json})"
				end
			end
		end
		
		class Game < R '/([a-zA-Z0-9_-]+)'
			def common
				if !game_exist? @gamename
					return 'No such game.'
				else
					@game = get_game @gamename
				end
				
				playerid, password = @cookies["game-#{@gamename}-playerid"].to_i, @cookies["game-#{@gamename}-password"]
				@loggedinas = @game.players.select.with_index{|pl, id| id==playerid and pl[:password]==password}[0]
				
				return nil
			end
			
			def get gamename
				@gamename = gamename
				err = common()
				return err if err
				
				if @game.over? and !@game.finished
					@game.finished = true
					
					finished = @game.players.select{|pl| pl[:letters].empty? }[0]
					adj = @game.players.map{|pl| pl[:letters].map{|lt| @game.board.letters_to_points[lt]}.inject(0, &:+) * -1  }
					
					adj[ finished[:id] ] = (adj.inject &:+) * -1 if finished
					
					@game.players.each_with_index do |pl, i|
						pl[:points] += adj[i]
					end
					
					
					adj.rotate! @game.whoseturn
					@game.history += adj.map{|pt| Scrabble::HistoryEntry.new(:adj, nil, nil, pt)}
				
					# save changes
					put_game @gamename, @game
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
						# this will raise Scrabble::WordError if anything's not right
						words = @game.board.check_word letts, @loggedinas[:letters], blank_replac, true
						# if we get here, we can assume all words are correct
						
						
						# TODO: move all this to Game class
						
						# sum up points
						score = words.map(&:score).inject(&:+) + (letts.length==7 ? 50 : 0) # "bingo"
						@loggedinas[:points] += score
						
						
						
						# which player goes next?
						@game.whoseturn = (@game.whoseturn+1) % @game.players.length
						
						# mark which multis were used
						letts.each do |col, row, _|
							@game.board.multis_used[row][col] = true
						end
						
						# remove used letters from rack, get new ones
						rack = @loggedinas[:letters].clone
						
						letts.each do |_, _, let|
							@loggedinas[:letters].delete_at @loggedinas[:letters].index let
						end
						@loggedinas[:letters] += @game.board.letter_queue.shift(7 - @loggedinas[:letters].length)
						
						
						# save the move data in history
						@game.history << Scrabble::HistoryEntry.new(:word, rack, words, score)
						@game.consec_passes = 0
						
						# save changes
						put_game @gamename, @game
						
						redirect "/#{@gamename}"
						
					rescue Scrabble::WordError => e
						return 'Incorrect move.'.encode('utf-8') + e.message.encode('utf-8') + get(@gamename).to_s.encode('utf-8')
					end
				
				elsif @request['mode'] == 'Pas/Wymiana'
					ch = @request['change'].upcase_pl.gsub(/\s/, '').split('')
					add = []
					
					rack = @loggedinas[:letters].clone
					
					# ch may contain other stuff, apart from letters. make sure we have letters,
					# then remove them from rack and add to queue
					ch.each do |let|
						ind = @loggedinas[:letters].index let
						if ind
							return "can't change if less than 7 letters left" if @game.board.letter_queue.length<7
							
							@loggedinas[:letters].delete_at ind
							add << let
						end
					end
					# get new letters from queue
					@loggedinas[:letters] += @game.board.letter_queue.shift(7 - @loggedinas[:letters].length)
					
					# add changed letters to queue and reshuffle
					@game.board.letter_queue = (@game.board.letter_queue + add).shuffle
					
					# which player goes next?
					@game.whoseturn = (@game.whoseturn+1) % @game.players.length
					
					
					# save the move data in history
					@game.history << Scrabble::HistoryEntry.new(((add.empty? ? :pass : :change)), rack, add.length, nil)
					@game.consec_passes += 1 # change counts, too.
					
					# save changes
					put_game @gamename, @game
					
					redirect "/#{@gamename}"
					
				end
			
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
				
				as = @game.players.select{|pl| pl[:password]==@password}[0]
				
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
		def layout
			html do
				head do
					title(@pagetitle ? "Scrabble - #{@pagetitle}" : "Scrabble")
					link rel:'stylesheet', type:'text/css', href:'/style.css'
					script '', type:'text/javascript', src:'/script.js'
				end
				body do
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
				text 'Liczba graczy: '; input.players!; br
				text 'Nicki kolejnych graczy (opcj.): '
				(0..3).each do |i|
					input name:"player#{i}"; text ' '
				end
				input type:'submit'
			end
		end
		
		def _board
			board = @game.board.board
			
			div.board! do
				board.each_index do |row|
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
				@game.players.each do |plhash|
					theclass = [
						'player', 
						(@loggedinas==plhash ? 'you' : ''),
						(@game.is_winner?(plhash) ? 'winner' : '')
					].join ' '
					
					div 'class' => theclass do
						if plhash[:id] == @game.whoseturn and !@game.over?
							img.currentimg src:'/arrow.gif'
						end
						
						if @loggedinas==plhash
							p{b plhash[:name]}
						else
							p plhash[:name]
						end
						
						p{b 'Admin gry'} if plhash[:admin]
						
						p "Hasło do dołączenia: #{plhash[:password]}" if @loggedinas and @loggedinas[:admin]
						
						p "Punkty: #{plhash[:points]}"
						
						if @loggedinas == plhash or @game.over?
							p "Litery: #{plhash[:letters].join ' '}"
						else
							p "Liter: #{plhash[:letters].length}"
						end
					end
				end
			end
		end
		
		def _gameinfo
			if @game.over?
				p.whoseturn! "Gra zakończona!"
			else
				p.whoseturn! "Teraz: #{@game.players[@game.whoseturn][:name]}"
			end
			
			p.letterleft! "Zostało: #{@game.board.letter_queue.length} liter"
		end
		
		def _history
			table.history! do
				tr do
					@game.players.each do |pl|
						th pl[:name]
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
		
		def game
			form method:'post', action:R(Game, @gamename) do
				_board
				br
				
				if @loggedinas and !@game.over?
					div.controls! do
						if @loggedinas[:letters].include? '?'
							br
							text 'Jeśli używasz blanka, wpisz tu, jaką literą chcesz go zastąpić: '
							input.blank_replac!
							if @loggedinas[:letters].count('?') > 1
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
				_gameinfo
				_players
				_history
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
			
			if !@loggedinas
				form.joingame! method:'post', action:R(JoinGame) do
					input.game! type:'hidden', value:@gamename
					text 'Dołącz go gry - hasło: '; input.password!
					input type:'submit'
				end
			end
			
			script <<EOF, type:'text/javascript'
				gamename = '#{@gamename}'
				hist_len = #{@game.history.length}
				document.body.addEventListener('keypress', arrow_listener, true)
				setInterval(scrabble_check, #{$production ? 3000 : 15000})
EOF
		end
	end
end

