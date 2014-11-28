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
	Dom.div !->
		Dom.style Box: "inline middle"
		Dom.div !->
			Dom.text tr("Selfies per day: ")
		renderCountInput()

exports.render = ->
	if Page.state.get(0) and Page.state.get(1)
		renderPhoto Page.state.get(0), Page.state.get(1)
		return
	
	Dom.div !->
		Dom.style padding: '16px 0', textAlign: 'center', fontSize: '200%'
		Dom.text "The Selfie Machine"

	left = Obs.create(0)
	Dom.section !->
		if Db.shared.get('sessions', Db.shared.get('sessionId'), 'open')
			Dom.style display: 'none'
			return
		Dom.style display: 'block'

		l = left.get()
		if !l
			Dom.text tr("By starting a new round, all members of this Happening will be asked to make a selfie within 5 minutes!")
			Ui.bigButton tr("New selfie round"), !-> left.set 4
			return
		Dom.style
			display: 'block'
			fontSize: '120%'
			textAlign: 'center'
		Dom.text tr("%1s...", l)
		Ui.button tr("Cancel"), !-> left.set 0
		Obs.onTime 1000, !->
			if not left.incr(-1)
				Server.call 'start'

	Db.shared.iterate 'sessions', (session) !->
		Dom.section !->
			open = session.get('open')
			if open
				Dom.h2 !->
					Dom.text tr("Ongoing selfie round")
					Dom.text " • "
					Time.deltaText session.get('open'), 'countdown'
				Dom.style background: '#fff9b7'

			else
				Dom.h2 !->
					Dom.text "Selfie round "
					Time.deltaText session.get('time')
				Dom.style background: ''

			Dom.div !->
				session.iterate 'selfies', (selfie) !->
					Dom.div !->
						Dom.style
							display: 'inline-block'
							margin: '4px'
							width: '150px'
							height: '150px'
							background: "url(#{Photo.url selfie.get('key'), 200}) 50% 50% no-repeat"
							backgroundSize: 'cover'
							position: 'relative'

						Ui.avatar Plugin.userAvatar(selfie.get('userId')), !->
							Dom.style position: 'absolute', bottom: '4px', right: '4px', margin: 0

						if +selfie.key() is Plugin.userId()
							Ui.button !->
								Dom.style position: 'absolute', left: '4px', bottom: '4px'
								Dom.text tr("Change")
							, !->
								Photo.pick()
						Dom.onTap !->
							Page.nav [session.key(), selfie.key()]

			empty = session.empty('selfies')
			Obs.observe !->
				return if not empty.get()
				Dom.div !->
					Dom.style padding: '8px 0'
					Dom.text tr("No selfies submitted in this round")

			Obs.observe !->
				if open and !session.get('selfies', Plugin.userId())
					Ui.bigButton !->
						Dom.div !->
							Dom.style fontSize: '180%', textAlign: 'center', padding: '4px'
							Time.deltaText session.get('open'), 'countdown'
						Dom.text tr("Make selfie!")
					, !->
						Photo.pick()

			Obs.observe !->
				showComments = Page.state.get('showComments', session.key())
				showComments ?= +session.key() == Db.shared.get('sessionId')
				if showComments
					Dom.div !->
						Dom.style
							background: '#fff'
							borderRadius: '6px'
							border: 'solid 1px #aaa'
						Social.renderComments session.key()
				else
					Dom.div !->
						Dom.style textAlign: 'center'
						Ui.button tr("Show comments"), !->
							Page.state.set 'showComments', session.key(), true

	, (session) -> -session.key()

renderPhoto = (sessionId, userId) !->
	Dom.style padding: 0
	photo = Db.shared.ref 'sessions', sessionId, 'selfies', userId

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


renderCountInput = (opts={}) !->

	[handleChange,orgValue] = Form.makeInput opts
	count = Obs.create orgValue ? 2
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
