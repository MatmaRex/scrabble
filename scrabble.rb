# coding: utf-8
require 'rufus-mnemo'
require 'rest-client'


class String
	def upcase_pl
		upcase.tr('ążśźęćńół', 'ĄŻŚŹĘĆŃÓŁ')
	end
	def downcase_pl
		downcase.tr('ĄŻŚŹĘĆŃÓŁ', 'ążśźęćńół')
	end
end

class Array
	def sort_by_pl
		order = 'aąbcćdeęfghijklłmnńoópqrsśtuvwxyzźż'
		order = order.upcase_pl + order
		
		self.sort_by{|let| order.index(let)||-1}
	end
end

module Scrabble
	class WordError < StandardError
	end
	
	class Word
		attr_accessor :col, :row, :direction, :letters, :board
		def initialize col, row, direction, letters, board
			@col, @row, @direction, @letters, @board = col, row, direction, letters, board
		end
		
		def length; @letters.length; end
		
		def to_s
			"Word@(#{@col},#{@row}#{@direction==:verti ? 'v' : 'h'}):#{@letters.join ''}(l=#{length},s=#{score})"
		end
		alias inspect to_s
		
		def score
			letter_scores = letters.map.with_index do |letter, ind|
				if @direction == :verti
					row = @row + ind
					col = @col
				else
					row = @row
					col = @col + ind
				end
					
				type = @board.boardtpl[row][col]
				multi = case type
				when :dl; 2
				when :tl; 3
				when :ql; 4
				when :t1; (@board.letters_to_points[letter.upcase_pl]==1 ? 3 : 1)
				when :t2; (@board.letters_to_points[letter.upcase_pl]==2 ? 3 : 1)
				when :t3; (@board.letters_to_points[letter.upcase_pl]==3 ? 3 : 1)
				when :t5; (@board.letters_to_points[letter.upcase_pl]==5 ? 3 : 1)
				else;     1
				end
				
				# for blanks, aka lowercase letters, this will be 0
				(@board.letters_to_points[letter]||0) * multi
			end
			
			word_multis = letters.map.with_index do |letter, ind|
				if @direction == :verti
					row = @row + ind
					col = @col
				else
					row = @row
					col = @col + ind
				end
					
				type = @board.boardtpl[row][col]
				
				@board.multis_used[row][col] ? 1 : (type==:dw ? 2 : type==:tw ? 3 : type==:qw ? 4 : 1)
			end
			
			letter_scores.inject(&:+) * word_multis.inject(&:*)
		end
	end
	
	module Definitions
		ScrabbleDef = {
			boardtpl: %w[
				tw nn nn dl nn nn nn tw nn nn nn dl nn nn tw
				nn dw nn nn nn tl nn nn nn tl nn nn nn dw nn
				nn nn dw nn nn nn dl nn dl nn nn nn dw nn nn
				dl nn nn dw nn nn nn dl nn nn nn dw nn nn dl
				nn nn nn nn dw nn nn nn nn nn dw nn nn nn nn
				nn tl nn nn nn tl nn nn nn tl nn nn nn tl nn
				nn nn dl nn nn nn dl nn dl nn nn nn dl nn nn
				tw nn nn dl nn nn nn dw nn nn nn dl nn nn tw
				nn nn dl nn nn nn dl nn dl nn nn nn dl nn nn
				nn tl nn nn nn tl nn nn nn tl nn nn nn tl nn
				nn nn nn nn dw nn nn nn nn nn dw nn nn nn nn
				dl nn nn dw nn nn nn dl nn nn nn dw nn nn dl
				nn nn dw nn nn nn dl nn dl nn nn nn dw nn nn
				nn dw nn nn nn tl nn nn nn tl nn nn nn dw nn
				tw nn nn dl nn nn nn tw nn nn nn dl nn nn tw
			].map(&:to_sym).each_slice(15).to_a, # as symbols, in rows of 15
			
			letter_freq: {
				'A'=>9, 'E'=>7, 'I'=>8, 'N'=>5, 'O'=>6, 'R'=>4, 'S'=>4, 'W'=>4, 'Z'=>5,
				'C'=>3, 'D'=>3, 'K'=>3, 'L'=>3, 'M'=>3, 'P'=>3, 'T'=>3, 'Y'=>4,
				'B'=>2, 'G'=>2, 'H'=>2, 'J'=>2, 'Ł'=>2, 'U'=>2,
				'Ą'=>1, 'Ę'=>1, 'F'=>1, 'Ó'=>1, 'Ś'=>1, 'Ż'=>1,
				'Ć'=>1,
				'Ń'=>1,
				'Ź'=>1,
				'?'=>2,
			},
			
			points_to_letters: {
				1 => %w[A E I N O R S W Z],
				2 => %w[C D K L M P T Y],
				3 => %w[B G H J Ł U],
				5 => %w[Ą Ę F Ó Ś Ż],
				6 => %w[Ć],
				7 => %w[Ń],
				9 => %w[Ź],
				0 => %w[?],
			},
		}
		
		LiterakiDef = {
			boardtpl: %w[
				t5 nn tw nn nn t2 nn t5 nn t2 nn nn tw nn t5
				nn nn nn nn t2 nn t5 nn t5 nn t2 nn nn nn nn
				tw nn nn t2 nn dw nn t1 nn dw nn t2 nn nn tw
				nn nn t2 nn dw nn t1 nn t1 nn dw nn t2 nn nn
				nn t2 nn dw nn t1 nn nn nn t1 nn dw nn t2 nn
				t2 nn dw nn t1 nn nn t3 nn nn t1 nn dw nn t2
				nn t5 nn t1 nn nn t3 nn t3 nn nn t1 nn t5 nn
				t5 nn t1 nn nn t3 nn t5 nn t3 nn nn t1 nn t5
				nn t5 nn t1 nn nn t3 nn t3 nn nn t1 nn t5 nn
				t2 nn dw nn t1 nn nn t3 nn nn t1 nn dw nn t2
				nn t2 nn dw nn t1 nn nn nn t1 nn dw nn t2 nn
				nn nn t2 nn dw nn t1 nn t1 nn dw nn t2 nn nn
				tw nn nn t2 nn dw nn t1 nn dw nn t2 nn nn tw
				nn nn nn nn t2 nn t5 nn t5 nn t2 nn nn nn nn
				t5 nn tw nn nn t2 nn t5 nn t2 nn nn tw nn t5
			].map(&:to_sym).each_slice(15).to_a, # as symbols, in rows of 15
			
			# standard
			letter_freq: ScrabbleDef[:letter_freq],
			
			points_to_letters: {
				1 => %w[A E I N O R S W Z],
				2 => %w[C D K L M P T Y],
				3 => %w[B G H J Ł U],
				5 => %w[Ą Ę F Ó Ś Ż Ć Ń Ź],
				0 => %w[?],
			},
		}
		
		Scrabble21Def = {
			boardtpl: %w[
				qw nn nn dl nn nn nn tw nn nn dl nn nn tw nn nn nn dl nn nn qw
				nn dw nn nn tl nn nn nn dw nn nn nn dw nn nn nn tl nn nn dw nn
				nn nn dw nn nn ql nn nn nn dw nn dw nn nn nn ql nn nn dw nn nn
				dl nn nn tw nn nn dl nn nn nn tw nn nn nn dl nn nn tw nn nn dl
				nn tl nn nn dw nn nn nn tl nn nn nn tl nn nn nn dw nn nn tl nn
				nn nn ql nn nn dw nn nn nn dl nn dl nn nn nn dw nn nn ql nn nn
				nn nn nn dl nn nn dw nn nn nn dl nn nn nn dw nn nn dl nn nn nn
				tw nn nn nn nn nn nn dw nn nn nn nn nn dw nn nn nn nn nn nn tw
				nn dw nn nn tl nn nn nn tl nn nn nn tl nn nn nn tl nn nn dw nn
				nn nn dw nn nn dl nn nn nn dl nn dl nn nn nn dl nn nn dw nn nn
				dl nn nn tw nn nn dl nn nn nn dw nn nn nn dl nn nn tw nn nn dl
				nn nn dw nn nn dl nn nn nn dl nn dl nn nn nn dl nn nn dw nn nn
				nn dw nn nn tl nn nn nn tl nn nn nn tl nn nn nn tl nn nn dw nn
				tw nn nn nn nn nn nn dw nn nn nn nn nn dw nn nn nn nn nn nn tw
				nn nn nn dl nn nn dw nn nn nn dl nn nn nn dw nn nn dl nn nn nn
				nn nn ql nn nn dw nn nn nn dl nn dl nn nn nn dw nn nn ql nn nn
				nn tl nn nn dw nn nn nn tl nn nn nn tl nn nn nn dw nn nn tl nn
				dl nn nn tw nn nn dl nn nn nn tw nn nn nn dl nn nn tw nn nn dl
				nn nn dw nn nn ql nn nn nn dw nn dw nn nn nn ql nn nn dw nn nn
				nn dw nn nn tl nn nn nn dw nn nn nn dw nn nn nn tl nn nn dw nn
				qw nn nn dl nn nn nn tw nn nn dl nn nn tw nn nn nn dl nn nn qw
			].map(&:to_sym).each_slice(21).to_a, # as symbols, in rows of 21
			
			# standard, doubled
			letter_freq: Hash[ ScrabbleDef[:letter_freq].to_a.map{|k,v| [k, v*2] } ],
			
			# standard
			points_to_letters: ScrabbleDef[:points_to_letters],
		}
	end
	
	class Board
		attr_accessor :board, :boardtpl, :points_to_letters, :letters_to_points, :base, :base_name
		attr_accessor :letter_freq, :letter_queue, :multis_used, :blank_replac
		
		def initialize base, base_name
			@base_name = base_name
			@base = base
			
			@boardtpl = @base[:boardtpl]
			@letter_freq = @base[:letter_freq]
			@points_to_letters = @base[:points_to_letters]
			
			
			@letters_to_points = {}
			@points_to_letters.each_pair{|val, letters| letters.each{|let| @letters_to_points[let]=val} }
			
			height = @boardtpl.length
			width  = @boardtpl[0].length
			
			@board = Array.new(height){Array.new width}
			@multis_used = Array.new(height){Array.new(width){false} }
			
			@letter_queue = @letter_freq.to_a.map{|let, n| [let]*n }.flatten.shuffle
			
			@blank_replac = {} # {[row, col] => 'X', ...}
		end
		
		def [] a
			@board[a]
		end
		
		def find_word_around col, row, direction # :horiz/:verti
			if direction == :horiz
				board = @board
				start = col
				start -= 1 until start==0 or board[row][start-1].nil?
				finish = col
				finish += 1 until finish==14 or board[row][finish+1].nil?
				
				major_word = Word.new start, row, :horiz, board[row][start..finish], self
			else
				board = @board.transpose
				start = row
				start -= 1 until start==0 or board[col][start-1].nil?
				finish = row
				finish += 1 until finish==14 or board[col][finish+1].nil?
				
				major_word = Word.new col, start, :verti, board[col][start..finish], self
			end
			
			return major_word
		end
		
		def place_word letters, rack, blank_replac
			# letters - array of col, row, letter
			# rack - array of letters
			# blank_replac - array of letters
			
			letters.map{|arr| arr[2] = arr[2].upcase_pl}
			
			
			# 0. sanity check - letters in the board range, single letters
			unless letters.all?{|col, row, letter| (0..14).include? col and (0..14).include? row and letter.length==1 and letters_to_points.keys.include? letter}
				raise WordError, '0. sanity check - malformed request? (use uppercase letters)'
			end
			
			
			
			# 1. check if all letters are on single line
			cols = letters.map{|col, row, letter| col}
			rows = letters.map{|col, row, letter| row}
			
			if (a=cols.uniq).length==1
				verti=true; col=a[0]
			elsif (a=rows.uniq).length==1
				horiz=true; row=a[0]
			else
				raise WordError, '1. not all letters are on single line'
			end
			
			
			# 2. sanity check, attempt to place the letters on board
			letters.each do |col, row, letter|
				if @board[row][col].nil?
					@board[row][col] = letter
				else
					raise WordError, '2. sanity check - malformed request?'
				end
			end
			
			
			# 2.5. check if there is a letter in the middle - required for the first move
			# both dimensions should be odd numbers
			# we get *indices* of "half a board, round up"
			middle_height = (@board.length-1)/2
			middle_width  = (@board[0].length-1)/2
			
			unless @board[middle_height][middle_width]
				raise WordError, '2.5. first word must pass through the middle field'
			end
			
			
			# 2.5 check if all words are connected
			checks = Array.new(15){ Array.new(15){false} }
			(0..14).each do |row|
				(0..14).each do |col|
					if @board[row][col]
						id = "#{row}/#{col}"
						stack = []
						
						stack << [row, col] unless checks[row][col]
						until stack.empty?
							crow, ccol = *stack.shift
							checks[crow][ccol] = id
							
							stack << [crow-1, ccol  ] unless crow==0  or !@board[crow-1][ccol  ] or checks[crow-1][ccol  ]
							stack << [crow+1, ccol  ] unless crow==14 or !@board[crow+1][ccol  ] or checks[crow+1][ccol  ]
							stack << [crow  , ccol-1] unless ccol==0  or !@board[crow  ][ccol-1] or checks[crow  ][ccol-1]
							stack << [crow  , ccol+1] unless ccol==14 or !@board[crow  ][ccol+1] or checks[crow  ][ccol+1]
						end
					end
					
					
				end
			end
			
			
			if checks.flatten.uniq.length != 2 # only false and a single id allowed
				raise WordError, '2.5. all words must be connected'
			end
			
			
			# 3. check if letters form only one word (no spaces), and find that word
			major_word=nil
			
			if horiz
				min, max = cols.minmax
				if @board[row][min..max].include? nil
					raise WordError, '3. all letters must form a single word'
				else
					major_word = find_word_around min, row, :horiz
				end
			elsif verti
				min, max = rows.minmax
				if @board.transpose[col][min..max].include? nil
					raise WordError, '3. all letters must form a single word'
				else
					major_word = find_word_around col, min, :verti
				end
			end
			
			raise WordError, '3. no word found' if !major_word
			
			
			# 4. gather up all newly created words
			words = [major_word]
			
			# for each letter, check if there's a word in the non-major direction
			words += letters.map{|col, row, letter| find_word_around col, row, (horiz ? :verti : :horiz)}
			
			words = words.select{|word| word.length>1} # discard one-letter "words" (major_word can be one-letter, too)
			
			if words.empty? # the only word was one-letter long - can occur at beginning of game
				raise WordError, "4. one-letter words not allowed / you didn't really create a word"
			end
			
			
			# 4.5. only letters from rack are used
			# as late as here, since wrong placement errors are much more common
			lets = letters.map{|a| a[2]}
			unless lets.uniq.all?{|let| rack.count(let) >= lets.count(let)}
				raise WordError, '4.5. you can only use letters from your rack'
			end
			
			
			# 5. check the words in dictionary
			base = 'http://www.sjp.pl/'
			dop = %r|<p style="margin: 0; color: green;"><b>dopuszczalne w grach</b></p>|
			
			# only now we have to substitute the blanks
			# sort - first the topmost, leftmost, horizontal words
			words = words.sort_by{|w| [w.row, w.col, (w.direction==:verti ? 2 : 1)] }
			# now, go thru the word list, marking (on the board) where the blanks were used
			words.each do |w|
				w.letters.each_with_index do |let, ind|
					next if let!='?'
					
					if w.direction==:verti
						col = w.col
						row = w.row + ind
					else
						col = w.col + ind
						row = w.row
					end
					
					key = [row, col]
					# if this blank wasn't parsed yet
					if !@blank_replac[key]
						raise WordError, '5. no blank replacement given' if blank_replac.empty?
						@blank_replac[key] = blank_replac.shift
					end
					
					# for word checking and history, replace the blank with a letter
					# lowercase indicates this is a blank
					w.letters[ind] = @blank_replac[key].downcase_pl
				end
				
			end
			
			# actually checking words here
			words.each do |w|
				unless (RestClient.get base+(CGI.escape w.letters.join(''))) =~ dop
					raise WordError, '5. incorrect word: '+ w.letters.join('')
				end
			end
			
			# sort once again, this time by word length - so the most important words go first
			words = words.sort_by{|w| w.length}.reverse
			
			return words
		end
	end
	
	class HistoryEntry
		attr_accessor :mode, :rack, :words, :score
		def initialize mode, rack, words, score
			@mode, @rack, @words, @score = mode, rack, words, score
		end
		# alias - for exchanges
		def changed_count; words; end
		def changed_count=a; words=a; end
	end
	
	class Player
		attr_accessor :id, :name, :points, :letters, :password, :admin
		def initialize opts
			@id, @name, @points, @letters, @password, @admin = opts[:id], opts[:name], opts[:points], opts[:letters], opts[:password], opts[:admin]
		end
		def [] key
			warn "Player#[]: #{caller[0]}"
			instance_variable_get "@#{key}"
		end
		def []= key, val
			warn "Player#[]=: #{caller[0]}"
			instance_variable_set "@#{key}", val
		end
	end
	
	class Game
		attr_accessor :board, :players, :whoseturn
		attr_accessor :history
		attr_accessor :consec_passes
		attr_accessor :finished
		
		def initialize playercount, playernames, whoisadmin, mode
			defs = case mode
			when :scrabble;   Definitions::ScrabbleDef
			when :literaki;   Definitions::LiterakiDef
			when :scrabble21; Definitions::Scrabble21Def
			else; raise 'invalid mode'
			end
			
			@board = Board.new defs, mode
			
			@history = []
			@players = []
			@whoseturn = 0
			
			playercount.times do |i|
				@players[i] = Player.new(
					id: i,
					name: (playernames[i] and playernames[i]!='' ? playernames[i].strip : "Player #{i+1}"),
					points: 0,
					letters: [],
					password: Rufus::Mnemo.from_integer(rand(1e6)),
					admin: (whoisadmin == i)
				)
			end
			
			@players.each do |plhash|
				plhash.letters = @board.letter_queue.shift(7)
			end
		end
		
		def over?
			@players.any?{|pl| pl.letters.empty?} or (@consec_passes||0) >= @players.length*2
		end
		
		def do_move letts, blank_replac, playerid
			cur_player = @players[playerid]
			
			# this will raise Scrabble::WordError if anything's not right
			words = @board.place_word letts, cur_player.letters, blank_replac
			
			# if we get here, we can assume all words are correct
			
			
			# sum up points
			score = words.map(&:score).inject(&:+) + (letts.length==7 ? 50 : 0) # "bingo"
			cur_player.points += score
			
			
			# which player goes next?
			@whoseturn = (@whoseturn+1) % @players.length
			
			# mark which multis were used
			letts.each do |col, row, _|
				@board.multis_used[row][col] = true
			end
			
			# remove used letters from rack, get new ones
			rack = cur_player.letters.clone
			
			letts.each do |_, _, let|
				# can't use #delete since it can remove more than one letter, if player has many of the same
				cur_player.letters.delete_at cur_player.letters.index let
			end
			cur_player.letters += @board.letter_queue.shift(7 - cur_player.letters.length)
			
			
			# save the move data in history
			@history << HistoryEntry.new(:word, rack, words, score)
			@consec_passes = 0
		end
		
		def do_pass_or_change ch, playerid
			cur_player = @players[playerid]
			
			add = []
			
			rack = cur_player.letters.clone
			
			# remove letters from rack and add to queue, if player actually has them
			ch.each do |let|
				ind = cur_player.letters.index let
				if ind
					return "can't change if less than 7 letters left" if @board.letter_queue.length<7
					
					cur_player.letters.delete_at ind
					add << let
				end
			end
			# get new letters from queue
			cur_player.letters += @board.letter_queue.shift(7 - cur_player.letters.length)
			
			# add changed letters to queue and reshuffle
			@board.letter_queue = (@board.letter_queue + add).shuffle
			
			# which player goes next?
			@whoseturn = (@whoseturn+1) % @players.length
			
			
			# save the move data in history
			@history << HistoryEntry.new((add.empty? ? :pass : :change), rack, add.length, nil)
			@consec_passes ||= 0
			@consec_passes += 1 # change counts, too.
		end
		
		# Returns true if any changes were made, false otherwise.
		def do_endgame_calculations
			if over? and !@finished
				@finished = true
				
				finished = @players.select{|pl| pl.letters.empty? }[0]
				adj = @players.map{|pl| pl.letters.map{|lt| @board.letters_to_points[lt]}.inject(0, &:+) * -1  }
				
				adj[finished.id] = (adj.inject &:+) * -1 if finished
				
				@players.each_with_index do |pl, i|
					pl.points += adj[i]
				end
				
				
				adj.rotate! @whoseturn
				@history += adj.map{|pt| Scrabble::HistoryEntry.new(:adj, nil, nil, pt)}
				
				return true
			else
				return false
			end
		end
		
		def max_points
			@players.map{|pl| pl.points}.max
		end
		
		def is_winner? player
			if over? and finished
				player.points == max_points
			else
				false
			end
		end
	end
end
