Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
Form = require 'form'
Time = require 'time'
Colors = Plugin.colors()
Photo = require 'photo'
Social = require 'social'
{tr} = require 'i18n'

exports.renderSettings = !->
	return if Db.shared
	Dom.div !->
		Dom.style Box: "inline middle"
		Dom.div !->
			Dom.text tr("Selfie deadline:")
		renderCountInput name: 'deadline'
		Dom.div !->
			Dom.text tr("minutes")

exports.render = ->
	if Page.state.get(0)
		renderPhoto Page.state.get(0)
		return
	
	Dom.div !->
		Dom.style backgroundColor: '#fff', margin: '-4px -8px', padding: '8px', borderBottom: '2px solid #ccc'

		Dom.div !->
			Dom.style textAlign: 'center', padding: '16px 0'
			Dom.div !->
				Dom.style fontSize: '180%'
				Dom.text tr("The Selfie Machine")
			Dom.div !->
				open = Db.shared.get('open')
				has = !!Db.shared.get('selfies', Plugin.userId())
				if !has and !open
					Dom.text tr("You're too late, deadline passed!")
				else if !open
					Dom.text tr("Showing results")
				else if open and has
					Dom.text tr("Waiting for others: ")
					Time.deltaText open, 'countdown'

		Obs.observe !->
			open = Db.shared.get('open')
			if open and !Db.shared.get('selfies', Plugin.userId())
				Dom.div !->
					Dom.style padding: '0 8px'
					Ui.bigButton !->
						Dom.div !->
							Dom.style fontSize: '180%', textAlign: 'center', padding: '4px'
							Time.deltaText open, 'countdown'
						Dom.text tr("Take selfie!")
					, !->
						Photo.pick()

		Dom.style padding: '2px'
		boxSize = Obs.create()
		Obs.observe !->
			width = Dom.viewport.get('width')
			cnt = (0|(width / 140)) || 1
			boxSize.set(0|(width-((cnt+1)*4))/cnt)

		if title = Plugin.title()
			Dom.h2 !->
				Dom.style margin: '6px 2px'
				Dom.text title

		Db.shared.iterate 'selfies', (photo) !->
			Dom.div !->
				Dom.style
					display: 'inline-block'
					margin: '2px'
					width: boxSize.get() + 'px'
				Dom.div !->
					Dom.style
						display: 'inline-block'
						height: boxSize.get() + 'px'
						width: boxSize.get() + 'px'
						background: "url(#{Photo.url photo.get('key'), 200}) 50% 50% no-repeat"
						backgroundSize: 'cover'
						position: 'relative'

					Ui.avatar Plugin.userAvatar(photo.key()), !->
						Dom.style position: 'absolute', bottom: '4px', right: '4px', margin: 0

					if +photo.key() is Plugin.userId()
						Ui.button !->
							Dom.style position: 'absolute', left: '4px', bottom: '4px'
							Dom.text tr("Change")
						, !->
							Photo.pick()
					Dom.onTap !->
						Page.nav [photo.key()]


		Obs.observe !->
			if !Db.shared.get('open') and Db.shared.empty('selfies').get()
				Dom.div !->
					Dom.style padding: '8px 0'
					Dom.text tr("No selfies submitted in this round")

	Dom.div !->
		Dom.style margin: '0 -8px'
		Social.renderComments()


renderPhoto = (userId) !->
	Dom.style padding: 0
	photo = Db.shared.ref 'selfies', userId

	byUserId = photo.get('userId')

	Page.setTitle tr("Selfie")

	contain = Obs.create false
	Dom.div !->
		Dom.style
			position: 'relative'
			height: Dom.viewport.get('width') + 'px'
			width: Dom.viewport.get('width') + 'px'
			backgroundColor: '#333'
			backgroundImage: Photo.css photo.get('key'), 800
			backgroundPosition: '50% 50%'
			backgroundSize: if contain.get() then 'contain' else 'cover'
			backgroundRepeat: 'no-repeat'
		Dom.onTap !->
			contain.set !contain.peek()

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
	count = Obs.create orgValue ? 5
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
		Dom.style Box: 'vertical center'
		renderArrow 1, !->
			count.incr()
		Dom.input !->
			inputE = Dom.get()
			Dom.prop
				size: 2
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
