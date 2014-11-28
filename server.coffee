Timer = require 'timer'
Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'

exports.onInstall = (config) !->
	time = 0|(Date.now()*.001)
	open = (if config? then config.deadline else 10)*60

	Db.shared.set
		time: time
		open: time+open
		selfies: {}

	Timer.set (open*.7)*1000, 'check'
	Timer.set open*1000, 'close'

	Event.create
		unit: 'xxx'
		text: "SELFIE: you have #{open/60}m!"

exports.check = !->
	f = []
	for id in Plugin.userIds()
		if not Db.shared.get('selfies', id)
			f.push id

	if f.length
		Event.create
			for: f
			unit: 'xxx'
			text: "SELFIE: reminder!"

exports.close = !->
	log 'close'
	Db.shared.remove 'open'

	count = 0
	for k of Db.shared.get('selfies')
		count++
	
	if count>1
		Event.create
			unit: 'xxx'
			text: "SELFIE: #{count} submissions"

exports.onPhoto = (info) !->
	log 'got photo', JSON.stringify(info), Plugin.userId()
	Db.shared.set 'selfies', Plugin.userId(), info

