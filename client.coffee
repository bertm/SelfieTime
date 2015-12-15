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
		if userId = +Page.state.peek(1)
			renderPhoto roundId, userId
			return

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
		Dom.h3 tr "Start Snap"
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
						Dom.text tr("All members will be asked to submit a “%1”-themed snap", newTitle)
					else
						Dom.text tr("All members will be asked to submit a snap")
				, !->
					if newTitle
						newTitle = newTitle[0].toUpperCase() + newTitle.substr(1)
					Event.subscribe [(Db.shared.get('maxId')||0)+1]
					Server.call 'newRound', newTitle
					inpE.value ''

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
		roundsShown = Obs.create 0
		Loglist.render lastV, firstV, (num) !->
			num = -num
			round = Db.shared.ref(num)
			return if round.get('open')

			roundsShown.incr()
			Obs.onClean !->
				roundsShown.incr(-1)
			Ui.item !->
				Dom.style Box: false, textAlign: 'right', padding: '8px 8px 0 8px'
				Dom.div !->
					Dom.style
						float: 'left'
						textAlign: 'left'
						paddingBottom: '8px'
					Event.styleNew round.get('time')
					Dom.text selfieTitle(round)
					Dom.div !->
						Dom.style color: '#aaa', fontSize: '75%'
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
				Event.renderBubble [num], style:
					margin: '4px 0 0 12px'

				Dom.div !->
					Dom.style clear: 'both'
				Dom.onTap !->
					Page.nav [num]
		Obs.observe !->
			if roundsShown.get() is 0
				Ui.emptyText "There are no finished rounds yet"
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
	cnt = (0|(width / 150)) || 1
	boxSize.set(0|(width-((cnt+1)*4))/cnt)


selfieTitle = (round) ->
	round.get('title') || Db.shared.get('title') || Plugin.title() || tr("It's snappening!")


renderRound = (roundId, preview) !->
	Page.setTitle tr("Snap round")

	round = Db.shared.ref(roundId)
	if !round.isHash()
		Ui.emptyText tr("No such round")
		return
	
	open = round.get('open')
	meDone = !!round.get('selfies', Plugin.userId())
	empty = round.empty('selfies').get()
	dummy = round.get('selfies') # the empty above doesn't appear to trigger a redraw on change (should it?) --Jelmer

	if open
		Event.markRead [] # new selfies are emitted on top level, we're seeing them here though (so clear 'm)

	Dom.div !->
		Dom.style textAlign: 'center', margin: '-8px -8px 8px -8px', padding: '4px 0', borderBottom: '2px solid #ccc'
		Dom.cls 'currentRnd'

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
			# open round and user should still submit a selfie
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
			else
				Dom.div !->
					Dom.style padding: '0 8px'
					Ui.bigButton !->
						Dom.div !->
							Dom.style fontSize: '180%', textAlign: 'center', padding: '4px'
							Dom.text tr("Take a snap")
					, !->
						Event.subscribe [roundId]
						Photo.pick 'camera'
							# subscribe to both the plugin and this round!
				if empty
					Ui.emptyText tr "Be the first!"
				else
					Ui.emptyText tr "Take one yourself to see snaps by:"
					round.observeEach 'selfies', (selfie) !->
						Ui.avatar Plugin.userAvatar(selfie.key()),
							style: display: 'inline-block', verticalAlign: 'middle', marginBottom: '4px'
							onTap: !-> Plugin.userInfo(selfie.get('userId'))
					Event.renderBubble [round.key()]

		else if !open and empty
			Ui.emptyText tr "No snaps submitted. Booh!"

		if open and meDone and preview and !empty
			Dom.onTap !-> Page.nav [roundId]
			Dom.div !->
				Dom.style marginTop: '12px'
				renderSelfies roundId, open, true # preview thumbs
				Event.renderBubble [round.key()]

		else if !preview and !empty
			Dom.div !->
				Dom.style marginTop: '12px'
				renderSelfies roundId, open

		if byUserId = round.get('by')
			Dom.div !->
				Dom.style
					fontSize: '70%'
					color: '#aaa'
					padding: '16px 0 0'
				Dom.text tr("Round started by %1", Plugin.userName(byUserId))

	if !preview
		Event.showStar tr("this round")
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
				verticalAlign: 'middle'
				margin: '2px'
				width: size + 'px'
			Dom.div !->
				Dom.style
					display: 'inline-block'
					height: size + 'px'
					width: size + 'px'
					borderRadius: if preview then '2px' else '5px'
					background: "url(#{Photo.url photo.get('key'), 200}) 50% 50% no-repeat"
					backgroundSize: 'cover'
					position: 'relative'

				if !preview
					Dom.div !->
						Dom.style width: '100%', height: '100%'
						Dom.onTap !->
							Page.nav [roundId, photo.key()]

					Dom.div !->
						Dom.style
							position: 'absolute'
							bottom: 0
							left: 0
							right: 0
							Box: 'bottom'
							textAlign: 'left'
							padding: '24px 6px 6px 6px'
							color: 'white'
							background_: 'linear-gradient(top, rgba(0, 0, 0, 0) 0px, rgba(0, 0, 0, 0.6) 100%)'
							borderRadius: '0 0 5px 5px'
							pointerEvents: 'none'

						Dom.div !->
							Dom.style fontSize: '70%', marginBottom: '2px', fontWeight: 'bold', whiteSpace: 'nowrap', pointerEvents: 'auto', Flex: 1
							Social.renderLike
								path: [roundId]
								id: 'p'+photo.key()
								userId: photo.get('userId')
								noExpand: true
								aboutWhat: tr("snap")
								color: '#fff'

						Ui.avatar Plugin.userAvatar(photo.get('userId')),
							size: 28
							style: margin: 0, backgroundColor: 'white', pointerEvents: 'auto'
							onTap: !-> Plugin.userInfo(photo.get('userId'))

					if open and +photo.key() is Plugin.userId()
						Ui.button !->
							Dom.style position: 'absolute', left: '4px', top: '4px'
							Dom.text tr("Change")
						, !->
							Photo.pick 'camera'




renderPhoto = (roundId, userId) !->
	photo = Db.shared.ref roundId, 'selfies', userId
	if !photo.isHash()
		Ui.emptyText tr("No such photo")
		return

	Dom.style padding: 0
	require('photoview').render
		current: photo.key()
		fullHeight: true
		content: (identifier) !->
			photo = Db.shared.ref roundId, 'selfies', identifier
			byUserId = photo.get('userId')
			if byUserId is Plugin.userId()
				Page.setTitle tr("Your snap")
			else
				Page.setTitle tr("Snap by %1", Plugin.userName(byUserId))
			Page.state.set 1, identifier
		getNeighbourIds: (id) ->
			foundMain = foundNext = false
			last = left = right = undefined
			Plugin.users.iterate (user) !->
				return if foundNext
				if foundMain and Db.shared.isHash(roundId, "selfies", user.key())
					right = user.key()
					foundNext = true
				if (foundMain = (user.key()+"") is (id+"") || foundMain)
					left = last
				if !foundMain and Db.shared.isHash(roundId, "selfies", user.key())
					last = user.key()
			left = last
			left = undefined if !Db.shared.isHash(roundId, "selfies", left)
			right = undefined if !Db.shared.isHash(roundId, "selfies", right)
			[left,right]
		idToPhotoKey: (id) ->
			Db.shared.get(roundId, "selfies", id, "key")



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
		Dom.style margin: '-8px -8px 0 -8px'

		if !Db.shared
			Form.box !->
				Form.input
					name: '_title'
					text: tr("Optional theme")

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


Dom.css
	'.currentRnd':
		backgroundColor: '#fff'
	'.currentRnd.tap':
		backgroundColor: '#eee'
