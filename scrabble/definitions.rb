# coding: utf-8

module Scrabble
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
			
			dict_check: :dict_check_pl,
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
			
			letter_freq: ScrabbleDef[:letter_freq],
			
			points_to_letters: {
				1 => %w[A E I N O R S W Z],
				2 => %w[C D K L M P T Y],
				3 => %w[B G H J Ł U],
				5 => %w[Ą Ę F Ó Ś Ż Ć Ń Ź],
				0 => %w[?],
			},
			
			dict_check: ScrabbleDef[:dict_check],
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
			
			points_to_letters: ScrabbleDef[:points_to_letters],
			
			dict_check: ScrabbleDef[:dict_check],
		}
		
		ScrabbleEnglishDef = {
			boardtpl: ScrabbleDef[:boardtpl],
			
			letter_freq: {
				'E'=>12, 'A'=>9, 'I'=>9, 'O'=>8, 'N'=>6, 'R'=>6, 'T'=>6, 'L'=>4, 'S'=>4, 'U'=>4,
				'D'=>4, 'G'=>3,
				'B'=>2, 'C'=>2, 'M'=>2, 'P'=>2,
				'F'=>2, 'H'=>2, 'V'=>2, 'W'=>2, 'Y'=>2,
				'K'=>1,
				'J'=>1, 'X'=>1,
				'Q'=>1, 'Z'=>1,
				'?'=>2,
			},
			
			points_to_letters: {
				1 => %w[E A I O N R T L S U],
				2 => %w[D G],
				3 => %w[B C M P],
				4 => %w[F H V W Y],
				5 => %w[K],
				8 => %w[J X],
				10=> %w[Q Z],
				0 => %w[?],
			},
			
			dict_check: :dict_check_en,
		}
		
		Scrabble21EnglishDef = {
			boardtpl: Scrabble21Def[:boardtpl],
			
			# this is not simply doubled normal
			letter_freq: {
				'E'=>24, 'A'=>16, 'O'=>15, 'T'=>15, 'I'=>13, 'N'=>13, 'R'=>13, 'S'=>10, 'L'=>7, 'U'=>7,
				'D'=>8, 'G'=>5,
				'C'=>6, 'M'=>6, 'B'=>4, 'P'=>4,
				'H'=>5, 'F'=>4, 'W'=>4, 'Y'=>4, 'V'=>3,
				'K'=>2,
				'J'=>2, 'X'=>2,
				'Q'=>2, 'Z'=>2,
				'?'=>4,
			},
			
			points_to_letters: ScrabbleEnglishDef[:points_to_letters],
			
			dict_check: ScrabbleEnglishDef[:dict_check],
		}
	end
end
