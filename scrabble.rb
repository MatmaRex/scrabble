# coding: utf-8
require 'set'
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

def load_dict
	# ugly, but oh well
	if !$dict
		data = File.open('slowa-win.txt', 'rb'){|f| f.readlines}
		data.map!{|s| s.force_encoding 'CP1250'}
		data.each{|s| s.chomp!}
		
		$dict = Set.new data
		GC.start
	end
	
	return $dict
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
				
				multi = @board.multis_used[row][col] ? 1 : (type==:dl ? 2 : type==:tl ? 3 : 1)
					
				@board.letters_to_points[letter] * multi
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
				
				@board.multis_used[row][col] ? 1 : (type==:dw ? 2 : type==:tw ? 3 : 1)
			end
			
			letter_scores.inject(&:+) * word_multis.inject(&:*)
		end
	end
	
	class Board
		attr_accessor :board, :boardtpl, :points_to_letters, :letters_to_points, :dict
		attr_accessor :letter_freq, :letter_queue, :multis_used
		
		def initialize board = Array.new(15){Array.new 15}
			@boardtpl = %w[
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
			].map(&:to_sym).each_slice(15).to_a # as symbols, in rows of 15
			
			@letter_freq = {
				'A'=>9, 'E'=>7, 'I'=>8, 'N'=>5, 'O'=>6, 'R'=>4, 'S'=>4, 'W'=>4, 'Z'=>5,
				'C'=>3, 'D'=>3, 'K'=>3, 'L'=>3, 'M'=>3, 'P'=>3, 'T'=>3, 'Y'=>4,
				'B'=>2, 'G'=>2, 'H'=>2, 'J'=>2, 'Ł'=>2, 'U'=>2,
				'Ą'=>1, 'Ę'=>1, 'F'=>1, 'Ó'=>1, 'Ś'=>1, 'Ż'=>1,
				'Ć'=>1,
				'Ń'=>1,
				'Ź'=>1
			}
			
			@points_to_letters = {
				1 => %W[A E I N O R S W Z],
				2 => %w[C D K L M P T Y],
				3 => %w[B G H J Ł U],
				5 => %w[Ą Ę F Ó Ś Ż],
				6 => %w[Ć],
				7 => %w[Ń],
				9 => %w[Ź],
			}
			
			@letters_to_points = {}
			@points_to_letters.each_pair{|val, letters| letters.each{|let| @letters_to_points[let]=val} }
			
			# @dict = load_dict
			
			@board = board
			@multis_used = Array.new(15){Array.new(15){false} }
			
			@letter_queue = @letter_freq.to_a.map{|let, n| [let]*n }.flatten.shuffle
		end
		
		# WORKAROUND FOR OLD GAMES
		def multis_used
			@multis_used ||= @board.map{|a| a.map{|b| !!b} }
			@multis_used
		end
		
		def clone
			Board.new(@board.dup.map &:dup) # deep-clone
		end
		alias dup clone
		
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
		
		def check_word letters, rack, do_write=false
			# letters - array of col, row, letter
			# rack - array of letters
			
			letters.map{|arr| arr[2] = arr[2].upcase_pl}
			
			
			# 0. sanity check - letters in the board range, single letters
			unless letters.all?{|col, row, letter| (0..14).include? col and (0..14).include? row and letter.length==1 and letters_to_points.keys.include? letter}
				raise WordError, '0. sanity check - malformed request? (use uppercase letters)'
			end
			
			
			# 0.5. only letters from rack are used
			lets = letters.map{|a| a[2]}
			unless lets.uniq.all?{|let| rack.count(let) >= lets.count(let)}
				raise WordError, '0.5. you can only use letters from your rack (use uppercase)'
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
			board_saved = self.clone
			
			letters.each do |col, row, letter|
				if @board[row][col].nil?
					@board[row][col] = letter
				else
					raise WordError, '2. sanity check - malformed request?'
				end
			end
			
			
			# 2.5. check if there is a letter in the middle - required for the first move
			unless @board[7][7]
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
			
			#5. check the words in dictionary
			base = 'http://www.sjp.pl/'
			dop = %r|<p style="margin: 0; color: green;"><b>dopuszczalne w grach</b></p>|
			
			words.each do |w|
				unless (RestClient.get base+(CGI.escape w.letters.join(''))) =~ dop
					raise WordError, '5. incorrect word: '+ w.letters.join('')
				end
			end
			
			
			# restore the board
			# TODO: fix this
			@board = board_saved.board unless do_write
			
			
			return words
		end
		
		def test
			require 'pp'
			
			# puts @dict.include? 'pąk'
			# puts @dict.include? 'zebra'
			
			PP.pp check_word [ [5, 8, 'u'], [5, 9, 'y'] ]
			PP.pp check_word [ [4, 7, 'u'], [4, 8, 'y'], [4, 9, 'z'] ]
			PP.pp check_word [ [5, 6, 'u'], [6, 6, 'y'], [7, 6, 'z'] ]
			
			
			PP.pp check_word([ [0,0, 'p'], [0,1, 'ą'], [0,2, 'k'] ])
			PP.pp check_word([ [0,0, 'p'], [0,1, 'ą'], [0,2, 'k'] ]).map &:score
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
	
	class Game
		attr_accessor :board, :players, :whoseturn
		attr_accessor :history
		
		def initialize playercount, mode = :scrabble
			@history = []
			
			@players = []
			@board = Board.new
			@whoseturn = 0
			
			playercount.times do |i|
				@players[i] = {
					id: i,
					name: "Player #{i+1}",
					points: 0,
					letters: [],
					password: Rufus::Mnemo.from_integer(rand(1e6)),
					admin: false
				}
			end
			
			@players[0][:admin] = true
			@players.each do |plhash|
				plhash[:letters] = @board.letter_queue.shift(7)
			end
		end
		
		def over?
			players.any?{|pl| pl[:letters].empty?}
		end
		
	end
end







if __FILE__ == $0
	bb = Scrabble::Board.new
	bb[7][5...(5+8)] = 'scrabble'.split ''

	bb.test
end