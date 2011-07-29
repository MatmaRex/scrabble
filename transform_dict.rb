# coding: cp1250
require 'set'


data = File.open('slowa-win.txt', 'rb'){|f| f.readlines}

data.map!{|s| s.force_encoding 'CP1250'}
data.each{|s| s.chomp!}


pl  = 'ążśźęćńół'
plu = 'ĄŻŚŹĘĆŃÓŁ'

data.map!{|s| s.upcase.tr pl, plu}

data.map!{|s| s.encode 'UTF-8'}



set = Set.new data

Marshal.dump set, File.open('dict-marshal', 'wb')