Timer = require 'timer'
Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'

exports.onInstall = ->

exports.client_start = !->
	if Db.shared.get('sessions', Db.shared.get('sessionId'), 'open')
		log 'cant start, open session'
		return

	sessionId = Db.shared.incr 'sessionId'
	time = 0|(Date.now()*.001)
	open = 120
	Db.shared.set 'sessions', sessionId,
		time: time
		open: time+open
		selfies: {}

	Timer.set (open/2)*1000, 'checkSession', sessionId
	Timer.set open*1000, 'closeSession', sessionId

	Event.create
		unit: 'xxx'
		text: "SELFIE round!"

exports.checkSession = (sessionId) !->
	f = []
	for id in Plugin.userIds()
		if not Db.shared.get('sessions', sessionId, 'selfies', id)
			f.push id

	if f.length
		Event.create
			for: f
			unit: 'xxx'
			text: "SELFIE reminder!"


exports.closeSession = (sessionId) !->
	log 'closeSession', sessionId
	Db.shared.remove 'sessions', sessionId, 'open'

	count = 0
	for k of Db.shared.get('sessions', sessionId, 'selfies')
		count++
	
	if count>1
		Event.create
			unit: 'xxx'
			text: "SELFIE: #{count} submissions"


exports.onPhoto = (info) !->
	session = Db.shared.ref('sessions', Db.shared.get('sessionId'))
	if !session
		log 'cant start, no session'
		return

	log 'got photo', JSON.stringify(info), Plugin.userId()
	session.set 'selfies', Plugin.userId(), info

