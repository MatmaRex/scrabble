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
		
		
		# home
		'Language: ' => 'Język: ',
		'Games list (admin: %s):' => 'Lista gier (admin: %s):',
		'manage' => 'zarządzaj',
		'Create new:' => 'Utwórz nową:',
		'Game name (allowed letters, numbers, _, -):' => 'Nazwa gry (dozwolone litery bez polskich znaków, cyfry, _, -):',
		'Player count (1-4):' => 'Liczba graczy (1-4):',
		'Player names (optional):' => 'Nicki kolejnych graczy (opcj.):',
		'I want to be player number (1-4, default 1):' => 'Chcę być graczem numer (1-4, domyślnie 1):',
		'Game type:' => 'Typ gry:',
		'Create game' => 'Utwórz grę', # button
		
		# manage
		'Deleted: ' => 'Usunięto: ',
		'Password: ' => 'Hasło: ',
		'Delete selected' => 'Usuń zaznaczone',
		
		# _players
		'Game admin' => 'Admin gry',
		'Join password: ' => 'Hasło do dołączenia: ',
		'Points: ' => 'Punkty: ',
		'Your letters: ' => 'Twoje litery: ',
		'Letters left: ' => 'Liter: ',
		
		# _gameinfo
		'Game over!' => 'Gra zakończona!',
		'Now: %s' => 'Teraz: %s',
		'%s letters left' => 'Zostało liter: %s',
		
		# _history
		'%{pts} points: %{word}' => '%{pts} punktów: %#{word}',
		'Pass.' => 'Pas.',
		'Exchange %s letters.' => 'Wymiana %s liter.',
		
		# _getblank
		'Swap a blank - provide its position: (for ex. B12) ' => 'Podmień blanka - podaj jego pozycję: (np. B12) ',
		
		# game
		'Rack: ' => 'Stojak: ',
		"If you're using a blank, which letter is it representing? " => 'Jeśli używasz blanka, jaką literę ma zastąpić? ',
		' (if using more than one at once, type in all the letters in order the blanks appear, the topmost, leftmost ones first)' => ' (jeśli używasz więcej niż jednego, wpisz litery po kolei, najpierw dla tego blanka, który jest najbliżej lewej strony lub góry planszy itd.)',
		'Legend: ' => 'Legenda: ',
		'Tile count: ' => 'Liczba płytek: ',
		'Join this game - password: ' => 'Dołącz go gry - hasło: ',
		'' => '',
		'' => '',
		'' => '',
		'' => '',
		'' => '',
		'' => '',
		'' => '',
		'' => '',
		'' => '',
		'' => '',
		'' => '',
		'' => '',
	},
	
	
}