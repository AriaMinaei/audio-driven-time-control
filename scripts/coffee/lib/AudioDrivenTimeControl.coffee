AudioTrack = require './audioDrivenTimeControl/AudioTrack'
array = require 'utila/scripts/js/lib/array'

module.exports = class AudioDrivenTimeControl

	constructor: (@context, destination = @context.destination) ->

		@node = @context.createGain()

		@node.connect destination

		@_isPlaying = no

		@_waitBeforePlay = 0.016

		@t = 0.0

		@duration = 0.0

		@_tracks = []

		@_queuedTracks = []

		@_lastContextTime = 0

	addTrack: (data, from = 0.0) ->

		track = new AudioTrack @, data, from

		@maximizeDuration from + track.duration

		@_tracks.push track

		@

	maximizeDuration: (duration) ->

		@duration = Math.max @duration, duration

	loadFull: ->

		lastPromise = null

		for t in @_tracks

			unless lastPromise?

				lastPromise = t.loadFull()

			else

				do (t) -> lastPromise.then => t.loadFull()

		lastPromise



	_unqueueAllTracks: ->

		loop

			track = @_queuedTracks.pop()

			break unless track?

			track.unqueue()

		return

	_unqueueTrack: (track) ->

		array.pluckOneItem @_queuedTracks, track

		return

	_queueTracksToPlay: ->

		for track in @_tracks

			continue if track in @_queuedTracks

			break if track.from - @_secondsToScheduleTrackInAdvance > @t

			continue if track.to < @t

			track.queue @t

			@_queuedTracks.push track

		return

	tick: (t) ->

		return unless @_isPlaying

		contextTime = @context.currentTime

		@t += contextTime - @_lastContextTime

		@_lastContextTime = contextTime

		# accurateTime = performance.now() / 1000.0

		# @t = @t + accurateTime - @_lastAccurateTime

		# @_lastAccurateTime = accurateTime

		if @t > @duration

			do @pause

			return

		i = 0

		loop

			track = @_queuedTracks[i]

			break unless track?

			if track.shouldUnqueue @t

				track.unqueue()

				@_queuedTracks.shift()

			else

				i++

		do @_queueTracksToPlay

		return

	play: ->

		return if @_isPlaying

		@_lastContextTime = @context.currentTime

		# @_lastAccurateTime = performance.now() / 1000.0

		@t -= @_waitBeforePlay

		do @_queueTracksToPlay

		@_isPlaying = yes

	pause: ->

		unless @_isPlaying

			throw Error "Already paused"

		do @_unqueueAllTracks

		@_isPlaying = no

		console.log 'pausing'