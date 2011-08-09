# coding: utf-8

module ScrabbleWeb
	module Views
		# Mab.set(:indent, 2) if !$production
		
		def layout
			titlebits = [
				@pagetitle, # may be nil - for index
				'Scrabble',
				($heroku ? '' : $production ? '(local)' : '(dev)')
			]
			
			html do
				head do
					title titlebits.select{|bit| bit and bit!=''}.join ' - '
					
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
			p.langs! do
				langs = %w[pl en]
				
				text loc 'Language: '
				langs.each do |lang|
					a lang, :href=>R(Lang, lang), :class=>(lang.to_sym==get_lang ? 'curlang' : '')
					text ' '
				end
			end
			
			p loc 'Sup.'
			
			p{loc('Games list (admin: %s):') % (a loc('manage'), href:R(Manage)).to_s}
			ul do
				@gamelist.each{|game| li{a game, href:"/#{game}"} }
			end
			
			p loc 'Create new:'
			form.create! method:'post', action:'/new!' do
				table do
					tr do
						td.prompt loc 'Game name (allowed letters, numbers, _, -):'
						td.value{input.gamename!}
					end
					tr do
						td.prompt loc 'Player count (1-4):'
						td.value{input.players!}
					end
					tr do
						td.prompt loc 'Player names (optional):'
						td.value do
							(0..3).each do |i|
								input name:"player#{i}"; text ' '
							end
						end
					end
					tr do
						td.prompt loc 'I want to be player number (1-4, default 1):'
						td.value{input.whoisadmin!}
					end
					tr do
						td.prompt loc 'Game type:'
						td.value do
							text loc 'In Polish: '
							label{ input type:'radio', name:'mode', value:'scrabble', checked:'checked'; text ' Scrabble ' }
							label{ input type:'radio', name:'mode', value:'scrabble21';                  text ' Super Scrabble ' }
							label{ input type:'radio', name:'mode', value:'literaki';                    text ' Literaki ' }
							br
							text loc 'In English: '
							label{ input type:'radio', name:'mode', value:'scrabbleen'  ;                text ' Scrabble' }
							label{ input type:'radio', name:'mode', value:'scrabble21en';                text ' Super Scrabble ' }
						end
					end
					tr do
						td.prompt ''
						td.value{input type:'submit', value:loc('Create game')}
					end
				end
			end
		end
		
		def manage
			if @deleted and !@deleted.empty?
				p loc('Deleted: ') + @deleted.join(', ')
			end
			
			form method:'post', action:R(Manage) do
				p{text loc 'Password: '; input.pass! type:'password'}
				
				ul do
					@gamelist.each do |gamename|
						li do 
							a gamename, href:"/#{gamename}"
							text ' '
							input name:"#{gamename}-kill", type:'checkbox'
						end
					end
				end
				
				input type:'submit', value:loc('Delete selected')
			end
		end
		
		def rawdataask
			form method:'post', action:R(RawData, @gamename) do
				p{text loc 'Password: '; input.pass! type:'password'}
				input type:'submit', value:loc('Get raw data')
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
						
						p{b loc 'Game admin'} if pl.admin
						
						p loc('Join password: ')+pl.password.to_s if @loggedinas and @loggedinas.admin
						
						p loc('Points: ')+pl.points.to_s
						
						if @loggedinas == pl or @game.over?
							p loc('Your letters: ')+pl.letters.join(' ')
						else
							p loc('Letters left: ')+pl.letters.length.to_s
						end
					end
				end
			end
		end
		
		def _gameinfo
			if @game.over?
				p.whoseturn! loc "Game over!"
			else
				p.whoseturn! loc("Now: %s") % @game.players[@game.whoseturn].name
			end
			
			p.letterleft! loc("%s letters left") % @game.board.letter_queue.length
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
									loc('%{pts} points: %{word}') % {pts: entry.score, word: entry.words.map{|w| w.letters.join ''}.join(', ')}
								elsif entry.mode == :pass
									loc 'Pass.'
								elsif entry.mode == :change
									loc('Exchange %s letters.') % entry.changed_count
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
						text loc 'Swap a blank - provide its position: (for ex. B12) '
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
						text loc 'Rack: '
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
							text loc "If you're using a blank, which letter is it representing? "
							input.blank_replac!
							if @loggedinas.letters.count('?') > 1
								text loc ' (if using more than one at once, type in all the letters in order the blanks appear, the topmost, leftmost ones first)'
							end
						end
						
						br
						input name:'mode', type:'submit', value:loc('OK')
						text ' '
						input type:'reset', value:loc('Redo')
						
						br
						input.change!
						text ' '
						input name:'mode', type:'submit', value:loc('Pass/Exchange' )
					end
				end
			end
			
			
			
			div.updateable! do
				_updateable
			end
			
			p.legend! do
				hsh = @game.board.letters_to_points
				order = hsh.keys.sort_by_pl
				
				b loc 'Legend: '
				text order.map{|let| "#{let}=#{hsh[let]}"}.join ', '
			end
			p.legend2! do
				hsh = @game.board.letter_freq
				order = hsh.keys.sort_by_pl
				
				b loc 'Tile count: '
				text order.map{|let| "#{let}x#{hsh[let]}"}.join ', '
			end
			
			if !@loggedinas and !@game.over?
				form.joingame! method:'post', action:R(JoinGame) do
					input.game! type:'hidden', value:@gamename
					text loc 'Join this game - password: '; input.password!
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