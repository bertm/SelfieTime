Db = require 'db'
Event = require 'event'
Photo = require 'photo'
Plugin = require 'plugin'
Timer = require 'timer'

exports.getTitle = -> # we're asking for _title in renderSettings

exports.onUpgrade = !->
	# fix non-initialized Snappening plugins
	if !Db.shared.get('maxId')? and !Db.shared.get('deadline')?
		exports.onInstall()

exports.onInstall = !->
    Db.shared.set 'maxId', 0
    Db.shared.set 'deadline', 120

exports.onConfig = (_config) !->
	config = _config || {}

	# write default deadline
	Db.shared.set 'deadline', (Math.min(480, config.deadline||120))

exports.client_newRound = exports.newRound = newRound = (title) !->
	# close current round (closes comments)
	maxId = Db.shared.incr 'maxId'
	if maxId>1
		Db.shared.remove maxId-1, 'open'

	log 'newRound', maxId

	time = 0|(Date.now()*.001)
	open = (Db.shared.get('deadline'))*60

	roundObj =
		time: time+open
		open: time+open
		selfies: {}
	if title
		roundObj.title = title
		roundObj.by = Plugin.userId()

	Db.shared.set maxId, roundObj

	Timer.cancel()
	Timer.set (open*.7)*1000, 'check'
	Timer.set open*1000, 'close'
		# notice how 'open' is *not* an absolute time! (contrary to what's in the data model)

	Event.create
		text: "Take a snap within #{open/60} minutes!"
		sender: Plugin.userId()

exports.check = !->
	round = Db.shared.ref (Db.shared.get 'maxId')
	f = []
	for id in Plugin.userIds()
		if not round.get('selfies', id)
			f.push id

	if f.length
		Event.create
			for: f
			text: "Snap reminder!"

exports.close = !->
	log 'close'
	maxId = Db.shared.get 'maxId'
	Db.shared.remove maxId, 'open'

exports.onPhoto = (info) !->
	log 'got photo', JSON.stringify(info), Plugin.userId()
	maxId = Db.shared.get 'maxId'
	round = Db.shared.ref maxId
	round.set 'selfies', Plugin.userId(), info
	Event.create
		text: "Snap by #{Plugin.userName()}"
		sender: Plugin.userId()

exports.client_remove = (roundId, userId) !->
	return if userId != Plugin.userId() and !Plugin.userIsAdmin()

	Photo.remove(key) if key = Db.shared.get(roundId, 'selfies', userId, 'key')
	Db.shared.remove(roundId, 'selfies', userId)

