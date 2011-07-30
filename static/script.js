function scrabble_callback(hsh)
{
	for(i in hsh)
	{
		if(i.match(/^\d+-\d+$/) && !document.getElementById(i).readonly)
		{
			document.getElementById(i).value = hsh[i]
			document.getElementById(i).readonly = true
			document.getElementById(i).className += ' disab'
		}
	}
	
	document.getElementById('updateable').innerHTML = hsh['updateable']
}

function scrabble_check()
{
	s = document.createElement('script')
	s.type = 'text/javascript'
	s.src = '/micro!/'+gamename+'?'+Math.random()
	document.getElementsByTagName('head')[0].appendChild(s)
}


function arrow_listener(e, _forced_target)
{
	me = (typeof _forced_target != 'undefined') ? _forced_target : e.target
	
	if(me.tagName.toLowerCase() != 'input' || me.parentNode.id != 'board') return
	
	v = e.keyCode==38 ? -1 : e.keyCode==40 ? +1 : 0
	h = e.keyCode==37 ? -1 : e.keyCode==39 ? +1 : 0
	
	if(v || h)
	{
		e.preventDefault()
		
		next = me.id.replace(/^(\d+)-(\d+)$/, function(_, a, b){return '' + (a*1 + v) + '-' + (b*1 + h)})
		nextel = document.getElementById(next)
		
		if(nextel)
		{
			if(nextel.readonly)
			{
				dummy = {preventDefault: function(){}, keyCode: e.keyCode}
				arrow_listener(dummy, nextel)
			}
			else
			{
				nextel.focus()
				nextel.select()
			}
		}
	}
}
