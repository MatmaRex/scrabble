# coding: utf-8

module ScrabbleWeb
	use Rack::Static, urls:['/static']
	
	module Controllers
		class Favicon < R '/favicon.ico'; def get; @headers['content-type']='image/vnd.microsoft.icon'; File.binread './favicon.ico'; end; end
		
		class Index
			def get
				@gamelist = get_list_of_games
				render :home
			rescue
				[$!.to_s, $!.backtrace].flatten.map{|a| a.force_encoding('cp1252')}.join "<br>"
			end
		end
		
		class Lang < R '/lang!/([a-z-]+)'
			def get lang
				@cookies['lang'] = lang
				redirect '/'
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
		
		class Kurnik < R '/raw!/([a-zA-Z0-9_-]+)'
			def get gamename
				@game = get_game gamename
				lines = []
				
				@game.players.each do |pl|
					lines << "##{pl.id+1} #{pl.name.gsub(/[^a-zA-Z0-9_-]/, '_')} : #{pl.points}"
				end
				lines << ''
				
				pl_count = @game.players.length
				@game.history.each_with_index do |entry, move_no|
					ln = []
					
					# move number - only on first player
					ln << "#{move_no/pl_count + 1}." if move_no%pl_count == 0
					
					# rack
					rack = entry.rack || @game.history[move_no - pl_count].rack # rack is empty for :adj entries
					ln << rack.join('').downcase_pl.gsub('?', '_') + ':'
					
					# word, pass, change, adj
					if entry.mode == :word
						# position
						mj_word = entry.words[0]
						ln << ('a'..'z').to_a[ mj_word.col ]  +  (mj_word.row+1).to_s  +  (mj_word.direction==:verti ? '+' : '-')
						
						# words
						ln << entry.words.map{|w| w.letters.map{|l| l.downcase_pl==l ? "[#{l}]" : l.downcase_pl}.join '' }.join('/')
						
						# points
						ln << "+#{entry.score}"
					elsif entry.mode == :change
						# we need to calculate difference between current and next rack
						curr_rack = entry.rack.clone
						next_rack = @game.history[move_no + pl_count].rack.clone
						
						# remove letters that occur in both racks
						kill = []
						curr_rack.each_with_index do |l, curr_ind|
							ind = next_rack.index l
							if ind
								next_rack.delete_at ind 
								kill << curr_ind
							end
						end
						kill.reverse_each{|i| curr_rack.delete_at i}
						
						# the letters left in both racks are the ones exchanged
						
						ln << curr_rack.join('').downcase_pl.gsub('?', '_') + ':'
						ln << '->'
						ln << next_rack.join('').downcase_pl.gsub('?', '_') + ':'
					elsif entry.mode == :pass
						ln << 'P'
					elsif entry.mode == :adj
						kind = (entry.score<=0 ? '-' : '+')
						
						if kind=='+' # if we got extra, there's nothing on rack
							ln.pop
							ln << ':'
						end
						
						ln << 'L'
						ln << kind + (entry.score.abs.to_s)
					end
					
					lines << ln.join(' ')
				end
				
				@headers['content-type'] = 'text/plain'
				lines.join "\n"
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
		
		class Manage < R '/manage!'
			def get
				@gamelist = get_list_of_games
				render :manage
			end
			
			def post
				return 'Wrong pass.' if @request['pass']!='magicznehaslo'
				
				@deleted = []
				
				@request.params.each_pair do |gameinfo, checked|
					if gameinfo =~ /-kill\Z/
						_, gamename = *gameinfo.match(/\A(.+)-kill\Z/)
						
						if checked and checked!=''
							delete_game gamename
							@deleted << gamename
						end
					end
				end
				
				@gamelist = get_list_of_games
				render :manage
			end
		end
		
		class Recalc < R '/recalc!/([a-zA-Z0-9_-]+)'
			def get gamename
				@game = get_game gamename
				@newgame = Scrabble::Game.new @game.players.length, @game.players.map(&:name), 0, :scrabble
				
				out = []
				
				@game.history.each_with_index do |entry, move_no|
					if entry.mode == :word
						letts = []
						entry.words.each do |word|
							word.letters.each_with_index do |lett, i|
								col = word.col + (word.direction == :verti ? 0 : i)
								row = word.row + (word.direction == :verti ? i : 0)
								letts << [col, row, lett] unless @newgame.board.board[row][col]
							end
						end
						letts.uniq!
						
						blank_replac = []
						letts.map! do |arr|
							if arr[2].downcase_pl==arr[2] # its a blank
								blank_replac << arr[2].upcase_pl
								arr[2] = '?'
							end
							
							arr
						end
						
						who = move_no % @game.players.length
						who_next = (move_no+1) % @game.players.length
						
						@newgame.players[who].letters = entry.rack.clone
						@newgame.do_move letts, blank_replac, who, true
						@newgame.whoseturn = who_next
						
						diff = @newgame.history[-1].score - entry.score
						out << diff if diff!=0
					elsif entry.mode == :change || entry.mode == :pass
						@newgame.history << entry
					end
				end
				
				put_game gamename+'-re', @newgame
				
				out.join '<br>'
			end
		end
	end
end
