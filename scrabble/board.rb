# coding: utf-8

module Scrabble
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
				(@board.letters_to_points[letter]||0) * (@board.multis_used[row][col] ? 1 :multi)
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
	
	class WordError < StandardError; end
	
	class Board
		attr_accessor :board, :boardtpl, :points_to_letters, :letters_to_points, :base, :base_name
		attr_accessor :letter_freq, :letter_queue, :multis_used, :blank_replac
		
		def initialize base, base_name
			@base_name = base_name
			@base = base
			
			@boardtpl = @base[:boardtpl]
			@letter_freq = @base[:letter_freq]
			@points_to_letters = @base[:points_to_letters]
			@dict_check = @base[:dict_check]
			
			
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
			warn "Board#[]: #{caller[0]}"
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
		
		def place_word letters, rack, blank_replac, force=false
			# letters - array of col, row, letter
			# rack - array of letters
			# blank_replac - array of letters
			
			letters.map{|arr| arr[2] = arr[2].upcase_pl}
			
			max_height = @board.length-1
			max_width  = @board[0].length-1
			
			# 0. sanity check - letters in the board range, single letters
			
			unless letters.all?{|col, row, letter| (0..max_width).include? col and (0..max_height).include? row and letters_to_points.keys.include? letter}
				raise WordError, '0. sanity check - malformed request?'
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
			# both dimensions should be odd numbers,
			# thus max_* is guaranteed to be even (indexing starts at 0),
			# and max_*/2 is guaranteed not to act funny.
			unless @board[max_height/2][max_width/2]
				raise WordError, '2.5. first word must pass through the middle field'
			end
			
			
			# 2.5 check if all words are connected
			checks = Array.new(max_height+1){ Array.new(max_width+1){false} }
			(0..max_height).each do |row|
				(0..max_width).each do |col|
					if @board[row][col]
						id = "#{row}/#{col}"
						stack = []
						
						stack << [row, col] unless checks[row][col]
						until stack.empty?
							crow, ccol = *stack.shift
							checks[crow][ccol] = id
							
							stack << [crow-1, ccol  ] unless crow==0          or !@board[crow-1][ccol  ] or checks[crow-1][ccol  ]
							stack << [crow+1, ccol  ] unless crow==max_height or !@board[crow+1][ccol  ] or checks[crow+1][ccol  ]
							stack << [crow  , ccol-1] unless ccol==0          or !@board[crow  ][ccol-1] or checks[crow  ][ccol-1]
							stack << [crow  , ccol+1] unless ccol==max_width  or !@board[crow  ][ccol+1] or checks[crow  ][ccol+1]
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
			unless force or lets.uniq.all?{|let| rack.count(let) >= lets.count(let)}
				raise WordError, '4.5. you can only use letters from your rack'
			end
			
			
			# 5. replace blanks
			
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
			
			
			#6. check the words in dictionary
			words.each do |w|
				w = w.letters.join('')
				unless force or method(@dict_check).call w
					raise WordError, '6. incorrect word: '+ w
				end
			end
			
			
			# sort once again, this time by word length - so the most important words go first
			words = words.sort_by{|w| w.length}.reverse
			
			# major word always goes first
			if major_word and major_word.length>1
				words.delete major_word
				words = [major_word] + words
			end
			
			return words
		end
	end
end
