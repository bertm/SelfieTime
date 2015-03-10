Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Loglist = require 'loglist'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Photo = require 'photo'
Page = require 'page'
Server = require 'server'
Social = require 'social'
Time = require 'time'
Ui = require 'ui'

Colors = Plugin.colors()
{tr} = require 'i18n'


exports.render = ->
	if roundId = +Page.state.get(0)
		if userId = +Page.state.get(1)
			renderPhoto roundId, userId
			return

		Event.showStar tr("this selfie round")
		renderRound roundId
		return

	roundId = Db.shared.get("maxId")
	if roundId && Db.shared.get(roundId,"open")
		renderRound roundId, true
	else
		renderNew()
	
	Form.sep()
	renderList()


renderNew = !->
	Dom.section !->
		Dom.h3 tr "Start self time"
		Dom.div !->
			Dom.style Box: 'middle'
			inpE = null
			Dom.div !->
				Dom.style Flex: 1, margin: '0 8px 0 0'
				inpE = Form.input
					name: 'title'
					text: tr("Optional theme")
			Ui.button tr("Start!"), !->
				newTitle = inpE.value().trim()
				Modal.confirm tr("Start a new round?"), !->
					if newTitle
						Dom.text tr("All members will be asked to submit a “%1”-themed selfie.", newTitle)
					else
						Dom.text tr("All members will be asked to submit a selfie.")
				, !->
					if newTitle
						newTitle = newTitle[0].toUpperCase() + newTitle.substr(1)
					Server.call 'newRound', newTitle
					inpE.value ''
		#if next = Db.shared.get('next')
		#	Dom.div !->
		#		Dom.style textAlign: 'right', color: '#666'
		#		Dom.text tr "Automatic selfie time "
		#		Time.deltaText next
		#		Dom.text "..."


renderList = !->

	if fv = Page.state.get('firstV')
		firstV = Obs.create(fv)
	else
		firstV = Obs.create(-Math.max(1, (Db.shared.peek('maxId')||0)-10))
	lastV = Obs.create()
		# firstV and lastV are inversed when they go into Loglist
	Obs.observe !->
		lastV.set -(Db.shared.get('maxId')||1)

	Ui.list !->
		Loglist.render lastV, firstV, (num) !->
			num = -num
			round = Db.shared.ref(num)
			return if round.get('open')

			Ui.item !->
				Dom.style Box: false, textAlign: 'right', padding: '8px 8px 0 8px'
				Dom.div !->
					Dom.style
						float: 'left'
						textAlign: 'left'
						paddingBottom: '8px'
					Event.styleNew round.get('time'), num
					Dom.text selfieTitle(round)
					Dom.div !->
						Dom.style color: '#aaa', fontSize: '75%'
						Event.renderBubble [num]
						Time.deltaText round.get('time')
				for k, v of round.get('selfies')
					Dom.div !->
						Dom.style
							display: 'inline-block'
							verticalAlign: 'top'
							height: '32px'
							width: '32px'
							margin: '0 0 8px 8px'
							background: "url(#{Photo.url v.key, 100}) 50% 50% no-repeat"
							backgroundSize: 'cover'
							borderRadius: '2px'
				Dom.div !->
					Dom.style clear: 'both'
				Dom.onTap !->
					Page.nav [num]

	Dom.div !->
		if firstV.get()==-1
			Dom.style display: 'none'
			return
		Dom.style
			padding: '4px'
			textAlign: 'center'

		Ui.button tr("Earlier rounds"), !->
			fv = Math.min(-1, firstV.peek()+10)
			firstV.set fv
			Page.state.set('firstV', fv)


boxSize = Obs.create()
Obs.observe !->
	width = Dom.viewport.get('width')
	cnt = (0|(width / 140)) || 1
	boxSize.set(0|(width-((cnt+1)*4))/cnt)


selfieTitle = (round) ->
	round.get('title') || Plugin.title() || tr("Selfie time!")


renderRound = (roundId, preview) !->
	round = Db.shared.ref(roundId)
	if !round.isHash()
		Ui.emptyText tr("No such round")
		return
	
	open = round.get('open')
	meDone = !!round.get('selfies', Plugin.userId())
	empty = round.empty('selfies').get()

	Dom.div !->
		Dom.style textAlign: 'center', backgroundColor: '#fff', margin: '-8px -8px 8px -8px', padding: '8px', borderBottom: '2px solid #ccc'

		Dom.div !->
			Dom.style fontSize: '180%'
			Dom.text selfieTitle(round)

		Dom.div !->
			if open
				Time.deltaText open, [
					60*60, 60*60, "%1 hour|s left"
					60, 60, "%1 minute|s left"
					0, 1, "just seconds left..."
					-Infinity, 1, "updating..."
				]
			else
				Dom.text tr "finished "
				Time.deltaText round.get('time')

		meUploading = Photo.uploads.count().get()

		if open && !meDone
			if meUploading
				Photo.uploads.observeEach (upload) !->
					Dom.div !->
						size = (if preview then 50 else boxSize.get()) + 'px'
						Dom.style
							margin: '2px'
							display: 'inline-block'
							Box: 'inline right bottom'
							height: size
							width: size
						if thumb = upload.get('thumb')
							Dom.style
								background: "url(#{thumb}) 50% 50% no-repeat"
								backgroundSize: 'cover'
						Dom.cls 'photo'
						Ui.spinner 24, !->
							Dom.style margin: '5px'
						, 'spin-light.png'
				return
			Dom.div !->
				Dom.style padding: '0 8px'
				Ui.bigButton !->
					Dom.div !->
						Dom.style fontSize: '180%', textAlign: 'center', padding: '4px'
						Dom.text tr("Take a selfie")
				, !->
					Photo.pick 'camera'
						# subscribe to both the plugin and this round!
			if empty
				Ui.emptyText tr "Be the first!"
				return
			Ui.emptyText tr "Take one yourself to see selfies by:"
			round.observeEach 'selfies', (selfie) !->
				Ui.avatar Plugin.userAvatar(selfie.key()),
					style: display: 'inline-block', verticalAlign: 'middle', marginBottom: '4px'
			return
		if empty
			Ui.emptyText tr "No selfies submitted. Booh!"

		if preview and meDone
			Dom.onTap !-> Page.nav [roundId]
			Dom.div !->
				Dom.style marginTop: '12px'
				renderSelfies roundId, open, true
			

	if preview
		return

	if !empty
		renderSelfies roundId, open
	
	Dom.div !->
		Dom.style margin: '12px -8px 0 -8px'
		Social.renderComments
			path: [roundId]
			key: 'r'+roundId # backwards compatibility



renderSelfies = (roundId,open,preview) !->
	Db.shared.observeEach roundId, 'selfies', (photo) !->
		Dom.div !->
			size = if preview then 30 else boxSize.get()
			Dom.style
				display: 'inline-block'
				margin: '2px'
				width: size + 'px'
			Dom.div !->
				Dom.style
					display: 'inline-block'
					height: size + 'px'
					width: size + 'px'
					background: "url(#{Photo.url photo.get('key'), 200}) 50% 50% no-repeat"
					backgroundSize: 'cover'
					position: 'relative'

				if !preview
					Ui.avatar Plugin.userAvatar(photo.key()),
						style: position: 'absolute', bottom: '4px', right: '4px', margin: 0

					if open and +photo.key() is Plugin.userId()
						Ui.button !->
							Dom.style position: 'absolute', left: '4px', bottom: '4px'
							Dom.text tr("Change")
						, !->
							Photo.pick 'camera'
					Dom.div !->
						Dom.style width: '100%', height: '100%'
						Dom.onTap !->
							Page.nav [roundId, photo.key()]


	
renderPhoto = (roundId, userId) !->
	photo = Db.shared.ref roundId, 'selfies', userId
	if !photo.isHash()
		Ui.emptyText tr("No such photo")
		return
	byUserId = photo.get('userId')
	if byUserId is Plugin.userId()
		Page.setTitle tr("Your selfie")
	else
		Page.setTitle tr("Selfie by %1", Plugin.userName(byUserId))

	Dom.style padding: 0
	require('photoview').render
		key: photo.get('key')
		fullHeight: true
		content: !->
			Dom.div !->
				Dom.style
					position: 'absolute'
					bottom: '5px'
					left: '10px'
					fontSize: '70%'
					textShadow: '0 1px 0 #000'
					color: '#fff'
				if byUserId is Plugin.userId()
					Dom.text tr("Added by you")
				else
					Dom.text tr("Added by %1", Plugin.userName(byUserId))



renderCountInput = (opts) !->

	[handleChange,orgValue] = Form.makeInput opts
	count = Obs.create orgValue ? opts.value
	Obs.observe !->
		handleChange count.get()

	renderArrow = (dir, onTap) !->
		Dom.div !->
			Dom.style
				width: 0
				height: 0
				borderStyle: "solid"
				borderWidth: "#{if dir>0 then 0 else 20}px 20px #{if dir>0 then 20 else 0}px 20px"
				borderColor: "#{if dir>0 then 'transparent' else Colors.highlight} transparent #{if dir>0 then Colors.highlight else Colors.highlight} transparent"
			Dom.onTap onTap
				
	Dom.div !->
		Dom.style Box: 'vertical center', margin: '8px'
		renderArrow 1, !->
			count.incr()
		Dom.input !->
			inputE = Dom.get()
			Dom.prop
				size: 3
				value: count.get()
			Dom.style
				fontFamily: 'monospace'
				fontSize: '30px'
				fontWeight: 'bold'
				textAlign: 'center'
				border: 'inherit'
				backgroundColor: 'inherit'
				color: 'inherit'
			Dom.on 'change input', !->
				count.set(+inputE.value())
			Dom.on 'click', !-> inputE.select()
		renderArrow -1, !->
			count.modify (v) -> if v <= 1 then 1 else v-1

	Form.make

exports.renderSettings = !->
	Dom.div !->
		Dom.style margin: '0 -8px 0 -8px'

		Form.box !->
			repeat = Db.shared?.get('repeat') ? 3

			getRepeatText = (r) ->
				if r is 0
					tr("Disabled")
				else if r is 1
					tr("Daily")
				else if r is 7
					tr("Weekly")
				else
					tr("Every %1 days", r)

			Dom.text tr("Automatic selfie time")
			[handleChange] = Form.makeInput
				name: 'repeat'
				value: repeat
				content: (value) !->
					Dom.div !->
						Dom.text getRepeatText(value)

			Dom.onTap !->
				Modal.show tr("Automatic selfie time"), !->
					Dom.style width: '60%'
					opts = [1, 3, 7, 0]
					Dom.div !->
						Dom.style
							maxHeight: '45.5%'
							overflow: 'auto'
							_overflowScrolling: 'touch'
							backgroundColor: '#eee'
							margin: '-12px'
						for rep in opts then do (rep) !->
							Ui.item !->
								Dom.text getRepeatText(rep)
								if repeat is rep
									Dom.style fontWeight: 'bold'

									Dom.div !->
										Dom.style
											Flex: 1
											padding: '0 10px'
											textAlign: 'right'
											fontSize: '150%'
											color: Plugin.colors().highlight
										Dom.text "✓"
								Dom.onTap !->
									handleChange rep
									repeat = rep
									Modal.remove()

		Form.sep()


		Dom.div !->
			Dom.style Box: "inline middle", margin: '0 8px 0 8px'
			Dom.div !->
				Dom.text tr("Deadline:")
			renderCountInput
				name: 'deadline'
				value: Db.shared?.get('deadline')||120
			Dom.div !->
				Dom.text tr("minutes")
