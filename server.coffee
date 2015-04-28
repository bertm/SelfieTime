Db = require 'db'
Event = require 'event'
Photo = require 'photo'
Plugin = require 'plugin'
Timer = require 'timer'

exports.getTitle = -> # we're asking for _title in renderSettings

exports.onUpgrade = !->
	# no next, but repeat is set? schedule new round..
	#if !Db.shared.get('next')? and (repeat = Db.shared.get('repeat'))>0
	#	scheduleNewRound repeat

	#if (open = Db.shared.get(1, 'open'))
	#	time = 0|(Date.now()*.001)
	#	if open < time
	#		Db.shared.remove 1, 'open'

	# fix non-initialized selfie-time plugins
	#if !Db.shared.get('maxId')? and !Db.shared.get('repeat')? and !Db.shared.get('deadline')?
	#	exports.onInstall()

oldUpgrade = !->
	# old data? upgrade!
	if (selfies = Db.shared.get('selfies'))?
		# comment muting (backend datastore)
		if (comments = Db.backend.get('comments', 'default'))?
			Db.backend.set 'comments', 'r1', comments
			Db.backend.remove 'comments', 'default'

		# comments and likes
		if (comments = Db.shared.get('comments', 'default'))?
			Db.shared.set 'comments', 'r1', comments
			Db.shared.remove 'comments', 'default'

		if (likes = Db.shared.get('likes'))?
			for id, like of likes
				[dum, nr] = id.split('-')
				Db.shared.set 'likes', 'r1-'+nr, like
				Db.shared.remove 'likes', id

		# now all personal stuff as well
		for uid in Plugin.userIds()
			if (commentNr = Db.personal(uid).get('comments', 'default'))?
				Db.personal(uid).set 'comments', 'r1', commentNr
				Db.personal(uid).remove 'comments', 'default'

			if (likes = Db.personal(uid).get('likes'))?
				for id, seenTime of likes
					[dum, nr] = id.split('-')
					Db.personal(uid).set 'likes', 'r1-'+nr, seenTime
					Db.personal(uid).remove 'likes', id
					
		# selfies / time / open
		Db.shared.set 'maxId', 1
		Db.shared.set 'repeat', 0
		Db.shared.set 1, 'selfies', selfies
		if (time = Db.shared.get('time'))?
			Db.shared.set 1, 'time', time
		if (open = Db.shared.get('open'))?
			Db.shared.set 1, 'open', open

		Db.shared.remove 'selfies'
		Db.shared.remove 'time'
		Db.shared.remove 'open'

exports.onInstall = exports.onConfig = (_config) !->
	config = _config || {}

	# write default deadline and repetition freq
	Db.shared.set 'deadline', (Math.min(480, config.deadline||120))
		# max 8 hour deadline (don't interfere with daily repeat setting)
	newRepeat = (config.repeat ? 3)
	oldRepeat = Db.shared.get 'repeat'
	Db.shared.set 'repeat', newRepeat
	if newRepeat is 0
		log 'repeat never, cancelling newRound timer'
		Timer.cancel 'newRound'
	else if !oldRepeat? or oldRepeat > newRepeat or oldRepeat is 0
		# this also schedules a new round when added through a template
		scheduleNewRound newRepeat

	if !Db.shared.get('maxId') and _config
		newRound() # initial round

scheduleNewRound = (repeat) !->
	return if !repeat

	dayStart = (Math.floor(Plugin.time()/86400) + repeat) * 86400
	Timer.cancel 'newRound'
	t = 0|(dayStart + (10*3600) + Math.floor(Math.random()*(12*3600)))
	Db.shared.set 'next', t
	if (t - Plugin.time()) > 3600
		Timer.set (t-Plugin.time())*1000, 'newRound'
		log 'new round scheduled', t
	else
		log 'next round too soon', t, Plugin.time()

exports.client_newRound = exports.newRound = newRound = (title) !->
	# close current round (closes comments)
	maxId = Db.shared.incr 'maxId'
	if maxId>1
		Db.shared.remove maxId-1, 'open'

	log 'newRound', maxId

	time = 0|(Date.now()*.001)
	open = (Db.shared.get('deadline')||120)*60

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

	scheduleNewRound (Db.shared.get('repeat') ? 3)

	Event.create
		unit: 'xxx'
		text: "Selfie deadline in #{open/60} minutes!"

exports.check = !->
	round = Db.shared.ref (Db.shared.get 'maxId')
	f = []
	for id in Plugin.userIds()
		if not round.get('selfies', id)
			f.push id

	if f.length
		Event.create
			for: f
			text: "Selfie reminder!"

exports.close = !->
	log 'close'
	maxId = Db.shared.get 'maxId'
	Db.shared.remove maxId, 'open'

exports.onPhoto = (info) !->
	log 'got photo', JSON.stringify(info), Plugin.userId()
	round = Db.shared.ref (Db.shared.get 'maxId')
	round.set 'selfies', Plugin.userId(), info
	Event.create
		unit: 'selfie'
		text: "Selfie by #{Plugin.userName()}"
		sender: Plugin.userId()

exports.client_remove = (roundId, userId) !->
	return if userId != Plugin.userId() and !Plugin.userIsAdmin()

	Photo.remove(key) if key = Db.shared.get(roundId, 'selfies', userId, 'key')
	Db.shared.remove(roundId, 'selfies', userId)

