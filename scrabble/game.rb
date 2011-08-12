# coding: utf-8

module Scrabble
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
		attr_accessor :board, :players, :whoseturn, :consec_passes
		attr_accessor :history, :finished, :chat
		
		def initialize playercount, playernames, whoisadmin, mode
			defs = case mode
			when :scrabble;     Definitions::ScrabbleDef
			when :literaki;     Definitions::LiterakiDef
			when :scrabble21;   Definitions::Scrabble21Def
			when :scrabbleen;   Definitions::ScrabbleEnglishDef
			when :scrabble21en; Definitions::Scrabble21EnglishDef
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
		
		def do_move letts, blank_replac, playerid, force=false
			cur_player = @players[playerid]
			
			# this will raise Scrabble::WordError if anything's not right
			words = @board.place_word letts, cur_player.letters, blank_replac, force
			
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
				@history += adj.map.with_index do |pt, i|
					Scrabble::HistoryEntry.new(:adj, @players[(@whoseturn+i) % @players.length].letters.clone, nil, pt)
				end
				
				return true
			else
				return false
			end
		end
		
		def do_chat msg, playerid
			@chat ||= []
			
			msg = msg.strip
			return if msg==''
			
			# prevent repeated messages
			this_guy_said = @chat.select{|ch| ch[:playerid]==playerid}
			unless this_guy_said.empty?
				return if this_guy_said[-1][:msg] == msg
			end
			
			@chat << {playerid: playerid, at: Time.now, msg: msg}
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
