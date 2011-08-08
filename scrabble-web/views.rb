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
				
				text 'Język: '
				langs.each do |lang|
					a lang, :href=>R(Lang, lang), :class=>(lang==get_lang ? 'curlang' : '')
					text ' '
				end
			end
			
			p 'Sup.'
			
			p{"Lista gier (admin: #{a 'zarządzaj', href:R(Manage)}):"}
			ul do
				@gamelist.each{|game| li{a game, href:"/#{game}"} }
			end
			
			p 'Utwórz nową:'
			form.create! method:'post', action:'/new!' do
				table do
					tr do
						td.prompt 'Nazwa gry (dozwolone litery bez polskich znaków, cyfry, _, -): '
						td.value{input.gamename!}
					end
					tr do
						td.prompt 'Liczba graczy (1-4): '
						td.value{input.players!}
					end
					tr do
						td.prompt 'Nicki kolejnych graczy (opcj.): '
						td.value do
							(0..3).each do |i|
								input name:"player#{i}"; text ' '
							end
						end
					end
					tr do
						td.prompt 'Chcę być graczem numer (1-4, domyślnie 1): '
						td.value{input.whoisadmin!}
					end
					tr do
						td.prompt 'Typ gry: '
						td.value do
							label{ input type:'radio', name:'mode', value:'scrabble', checked:'checked'; text ' Scrabble ' }
							label{ input type:'radio', name:'mode', value:'scrabble21';                  text ' Super Scrabble ' }
							label{ input type:'radio', name:'mode', value:'literaki';                    text ' Literaki ' }
							label{ input type:'radio', name:'mode', value:'scrabbleen'  ;                text ' Scrabble (English)' }
							label{ input type:'radio', name:'mode', value:'scrabble21en';                text ' Super Scrabble (English) ' }
						end
					end
					tr do
						td.prompt ''
						td.value{input type:'submit', value:'Utwórz grę'}
					end
				end
			end
		end
		
		def manage
			if @deleted and !@deleted.empty?
				p 'Usunięto: '+@deleted.join(', ')
			end
			
			form method:'post', action:R(Manage) do
				p{text 'Hasło: '; input.pass! type:'password'}
				
				ul do
					@gamelist.each do |gamename|
						li do 
							a gamename, href:"/#{gamename}"
							text ' '
							input name:"#{gamename}-kill", type:'checkbox'
						end
					end
				end
				
				input type:'submit', value:'Usuń zaznaczone'
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