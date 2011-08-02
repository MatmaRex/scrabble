function scrabble_callback(hsh)
{
	hist_len = hsh['hist_len']
	hilit = document.getElementsByClassName('hilit')
	while(hilit[0]) hilit[0].className = hilit[0].className.replace('hilit', '')
	
	for(i in hsh)
	{
		el = document.getElementById(i)
		
		if(i.match(/^\d+-\d+$/) && !el.readonly && el.value!=hsh[i])
		{
			el.className = el.className.replace('enab', 'disab') + ' hilit'
			el.readonly = true
			el.value = hsh[i]
		}
	}
	
	document.getElementById('updateable').innerHTML = hsh['updateable']
	if(hsh['over'])
	{
		con = document.getElementById('controls')
		con.parentNode.removeChild(con)
	}
}

function scrabble_check()
{
	s = document.createElement('script')
	s.type = 'text/javascript'
	s.src = '/micro!/'+gamename+'?hist_len='+hist_len+'&re='+Math.random()
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
			if(nextel.className.indexOf('disab') != -1)
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
