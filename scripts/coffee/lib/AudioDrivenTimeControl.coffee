wn = require 'when'
array = require 'utila/scripts/js/lib/array'
TrackPlayer = require './audioDrivenTimeControl/TrackPlayer'
CachedTrack = require './CachedTrack'
_Emitter = require './_Emitter'
Context = window.AudioContext || window.webkitAudioContext

module.exports = class AudioDrivenTimeControl extends _Emitter

	constructor: (destination = new Context, @id = 'audio') ->

		# the emitter
		super

		# setup the audio stuff
		if destination.context?

			@context = destination.context

		else

			@context = destination

			destination = @context.destination

		@node = @context.createGain()

		@node.connect destination

		# current time in milliseconds
		@t = 0.0

		@duration = 0.0

		@_tracksDuration = 0.0

		@_requestedDuration = 0.0

		@_waitBeforePlay = 16.0

		@_prescheduleFor = 1000.0

		# track players
		@_players = []

		# stuff for ready() and isReady() methods
		@_playersLeftToUpdate = 0

		@_isReady = yes

		@_readyDeferred = wn.defer()

		@_readyDeferred.resolve()

		# playback stuff
		@_isPlaying = no

		@_scheduledToPlay = no

		@_queuedPlayers = []

		@_lastWindowTime = 0.0

	add: (track, from = 0.0) ->

		if typeof track is 'string'

			track = new CachedTrack @context, track, @id

		player = new TrackPlayer @, track, from

		@_players.push player

		player

	# this is called whenever a player might have to load something,
	# or change its properties
	_waitForUpdate: (whenPlayerIsDonwWithUpdating) ->

		# pause the playback if necessary
		do @pause

		# the next ready() call might need a new promise
		do @_scheduleToGetReady

		@_playersLeftToUpdate++

		wn(whenPlayerIsDonwWithUpdating).then =>

			@_playersLeftToUpdate--

			do @_getReadyIfNecessary

			return

	# put a new promise for the ready() call
	_scheduleToGetReady: ->

		# only update the promise if this is called after the first
		# player that has requested a wait-for-an-update.
		if @_playersLeftToUpdate is 0

			@_isReady = no

			@_readyDeferred = wn.defer()

			@_emit 'ready-state-change'

	# if all players doing an update are done, we can resolve
	# our promise on the ready() call
	_getReadyIfNecessary: ->

		if @_playersLeftToUpdate is 0

			do @_updateEverything

			@_isReady = yes

			@_readyDeferred.resolve()

			@_emit 'ready-state-change'

	# resolves when all players are ready to be played
	ready: ->

		@_readyDeferred.promise

	# is ready to play
	isReady: ->

		@_isReady

	# maximize's the timeline's duration based on the arbitrary
	# value provided from maximizeDuration() or the length of the
	# audio timeline
	_updateDuration: ->

		newDuration = Math.max @_requestedDuration, @_tracksDuration

		if newDuration isnt @duration

			@duration = newDuration

			@_emit 'duration-change'

	# updates everything, if there is a change in the timeline
	_updateEverything: ->

		@_players.sort (b, a) ->

			b.from > a.from

		tracksDuration = 0.0

		for player in @_players

			tracksDuration = Math.max tracksDuration, player.to

		@_tracksDuration = tracksDuration

		do @_updateDuration

	# unqeueue all players if we must pause
	_unqueueAllPlayers: ->

		loop

			player = @_queuedPlayers.pop()

			break unless player?

			player._unqueue()

		return

	_queuePlayersToPlay: ->

		for player in @_players

			continue if player in @_queuedPlayers

			break if player.from - @_prescheduleFor > @t

			continue if player.to < @t

			player._queue @t

			@_queuedPlayers.push player

		return

	# tick must be called by requestAnimationFrame or something similar
	# byt the user
	tick: ->

		return unless @_isPlaying

		currentWindowTime = performance.now()

		@t += currentWindowTime - @_lastWindowTime

		@_lastWindowTime = currentWindowTime

		if @t > @duration

			do @pause

			@seekTo 0.0

			return

		i = 0

		loop

			player = @_queuedPlayers[i]

			break unless player?

			if player._shouldUnqueue @t

				player._unqueue()

				@_queuedPlayers.shift()

			else

				i++

		do @_queuePlayersToPlay

		@_emit 'tick', @t

		return

	# this is to set an arbitrary duration for the timeline,
	# but if it's smaller than the audio tracks` duration,
	# it won't affect the timeline's duration
	maximizeDuration: (duration) ->

		@_requestedDuration = duration

		do @_updateDuration

	play: ->

		return if @_isPlaying or @_scheduledToPlay

		# if we're ready...
		if @_isReady

			# ... just play
			do @_play

			return

		# we're not ready, so remember that we are scheduled to play
		@_scheduledToPlay = yes

		# we can emit an event too, so that UI can react to
		# the schedule to play
		@_emit 'scheduled-to-play'

		# now, wait to get ready...
		@ready().then =>

			# ... and if our schedule to play is not cancelled...
			if @_scheduledToPlay

				@_scheduledToPlay = no

				# ... play!
				do @_play

		return

	_play: ->

		return if @t > @duration

		@_lastWindowTime = performance.now()

		@t -= @_waitBeforePlay

		do @_queuePlayersToPlay

		@_isPlaying = yes

		@_emit 'play'

	pause: ->

		# if we're not playing...
		unless @_isPlaying

			# ... and we're scheduled to play,
			if @_scheduledToPlay

				# just cancel the schedule
				@_scheduledToPlay = no

				@_emit 'pause'

				return

		do @_unqueueAllPlayers

		@_isPlaying = no

		# we're playing, so emit a pause
		@_emit 'pause'

		return

	isPlaying: ->

		@_isPlaying

	getPlayState: ->

		# playing
		return 1 if @_isPlaying

		# scheduled to play
		return 2 if @_scheduledToPlay

		# paused
		return 0

	togglePlay: ->

		if @_isPlaying

			do @pause

		else

			do @play

	seekTo: (t) ->

		if @_isPlaying

			wasPlaying = yes

			do @pause

		if t > @duration then t = @duration

		if t < 0 then t = 0.0

		@_emit 'tick', @t = t

		if wasPlaying

			do @play

		return

	seek: (amount) ->

		@seekTo @t + amount