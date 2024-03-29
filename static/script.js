function scrabble_callback(hsh)
{
	hist_len = hsh['hist_len']
	hilit = document.getElementsByClassName('hilit')
	while(hilit[0]) hilit[0].className = hilit[0].className.replace('hilit', '')
	
	for(i in hsh)
	{
		if(i.match(/^\d+-\d+$/))
		{
			el = document.getElementById(i)
			
			if( el.className.indexOf('enab')!=-1 || el.value!=hsh[i] )
			{
				el.className = el.className.replace('enab', 'disab') + ' hilit'
				el.readonly = true
				el.value = hsh[i]
				
				// work around a nasty Opera bug where text-transform sticks on inputs
				if(window.opera)
				{
					if(el.nextSibling) el.parentNode.insertBefore(el, el.nextSibling)
					else el.parentNode.appendChild(el)
				}
			}
		}
	}
	
	document.getElementById('updateable').innerHTML = hsh['updateable']
	if(hsh['over'])
	{
		con = document.getElementById('controls')
		con.parentNode.removeChild(con)
		
		con = document.getElementById('getblank')
		con.parentNode.removeChild(con)
	}
}

function chat_callback(messages, len)
{
	chat_len = len
	
	chat = document.getElementById('chat')
	chat.innerHTML = messages + chat.innerHTML
}

function scrabble_check()
{
	s = document.createElement('script')
	s.type = 'text/javascript'
	s.src = '/micro!/'+gamename+'?hist_len='+hist_len+'&chat_len='+chat_len+'&re='+Math.random()
	document.getElementsByTagName('head')[0].appendChild(s)
}


function chat_post()
{
	msg = document.getElementById('msg').value
	
	s = document.createElement('script')
	s.type = 'text/javascript'
	s.src = '/chat!/'+gamename+'?js=yes&msg='+encodeURIComponent(msg)+'&re='+Math.random()
	document.getElementsByTagName('head')[0].appendChild(s)
}

function chat_posted()
{
	document.getElementById('msg').value = ''
	scrabble_check()
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

function dropzone_setup(n)
{
	for(var i=0; i<n; i++) mint.gui.RegisterDragObject("letter"+i)
	
	var zone = mint.gui.RegisterDropZone("rackdropzone")
	zone.autoInline = false
	zone.returnItems = true
	
	for(var i=0; i<n; i++) zone.InsertItem( document.getElementById("letter"+i) )
}
