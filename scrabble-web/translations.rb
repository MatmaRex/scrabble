# coding: utf-8

SCRABBLE_TRANSLATIONS = {
	en: {}, # has to be here to prevent errors when we get nil instead of hash
	
	pl: {
		# some generic errors repeated in a few places
		'No such game.' => 'Nie ma takiej gry.',
		'Not your turn.' => 'Nie twoja tura.',
		'Game already over.' => 'Gra już się zakończyła.',
		'Wrong password.'=> 'Nieprawidłowe hasło.',
		
		# NewGame errors
		'Players number incorrect.' => 'Nieprawidłowa liczba graczy.',
		'Chosen player number incorrect.' => 'Nieprawidłowy numer gracza.',
		"Game '%s' already exists." => "Gra '%s' już istnieje.",
		'Only ASCII letters, numbers, underscore and hyphen (a-z, A-Z, 0-9, _, -) allowed in game names.' => 'W nazwie gry dozwolone są tylko litery bez polskich znaków, cyfry, podkreślnik (_) i myślnik (-).',
		
		# GetBlank errors
		'Wrong input format?' => 'Nieprawidłowy format?',
		'Not a blank here.' => 'Na tym polu nie ma blanka.',
		"You don't have this letter." => 'Nie masz takiej litery.',
		
		# Game errors
		'You did nothing?' => 'Nic nie ułożyłeś?',
		'Incorrect move.' => 'Nieprawidłowy ruch.',
	},
	
	
}