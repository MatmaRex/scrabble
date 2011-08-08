# coding: utf-8

require './scrabble'

# this is a nasty fix. some versions of Markaby want to undef these methods, 
# and some versions of Builder do not define them,
# thus causing an exception. 
gem 'builder', '= 2.1.2'
require 'builder'
class Builder::BlankSlate
	unless method_defined? :to_s; def to_s; end; end
	unless method_defined? :inspect; def inspect; end; end
	unless method_defined? :==; def ==; end; end
end

require 'json'
require 'camping'
require 'pg' if $heroku


Camping.goes :ScrabbleWeb


require './scrabble-web/helpers.rb'
require './scrabble-web/controllers.rb'
require './scrabble-web/views.rb'
