# coding: utf-8
require 'rufus-mnemo'
require 'rest-client'


class String
	def upcase_pl
		self.force_encoding('utf-8').upcase.tr('ążśźęćńół', 'ĄŻŚŹĘĆŃÓŁ')
	end
	def downcase_pl
		self.force_encoding('utf-8').downcase.tr('ĄŻŚŹĘĆŃÓŁ', 'ążśźęćńół')
	end
end

class Array
	def sort_by_pl
		order = 'aąbcćdeęfghijklłmnńoópqrsśtuvwxyzźż'
		order = order.upcase_pl + order
		
		self.sort_by{|let| order.index(let)||-1}
	end
end


def dict_check_pl word
	response = RestClient.get 'http://www.sjp.pl/'+(CGI.escape word)
	response = response.encode('ascii-8bit', :invalid => :replace, :undef => :replace) # heroku throws up on "invalid bytes"
	
	response =~ %r|<p style="margin: 0; color: green;"><b>dopuszczalne w grach</b></p>|
end

def dict_check_en word
	payload = <<-SOAP
		<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
			<soap:Body>
				<CheckWord xmlns="http://tempuri.org/">
					<Word>#{word.upcase}</Word>
				</CheckWord>
			</soap:Body>
		</soap:Envelope>
	SOAP
	
	response = RestClient.post(
		'http://www.collinslanguage.com/widgets/webservices/CollinsScrabble.asmx',
		payload,
		'Content-type' => 'text/xml; charset=utf-8'
	)
	
	response =~ %r|<IsValidWord>True</IsValidWord>|
end


require './scrabble/definitions'
require './scrabble/board'
require './scrabble/game'
