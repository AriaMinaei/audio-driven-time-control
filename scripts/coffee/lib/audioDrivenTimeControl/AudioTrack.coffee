wn = require 'when'
TrackChunk = require './audioTrack/TrackChunk'

module.exports = class AudioTrack

	constructor: (@timeControl, @dataHandler, @from) ->

		@_chunks = []

		@context = @timeControl.context

		@duration = 0.0

		for chunkData in @dataHandler.split 2, 3

			@_chunks.push chunk = new TrackChunk @, chunkData

			@duration += chunk.duration

		@to = @from + @duration

		@_currentSource = null

		@queued = no

		@_queuedChunks = []

		@_secondsToQueueTrackInAdvance = 1

	loadFull: ->

		for p in @_chunks

			unless lastPromise?

				lastPromise = p.decode()

			else

				do (p) -> lastPromise = lastPromise.then -> p.decode()

		lastPromise

	_toLocalT: (rootT) ->

		rootT - @from

	_queueChunksFor: (localT) ->

		for chunk in @_chunks

			continue if chunk.to < localT

			continue if chunk.from - @_secondsToQueueTrackInAdvance > localT

			continue if chunk in @_queuedChunks

			chunk.queue localT

			@_queuedChunks.push chunk

		return

	queue: (rootT) ->

		if @queued

			throw Error "Track is already queued"

		@queued = yes

		localT = @_toLocalT rootT

		@_queueChunksFor localT

		return

	unqueue: ->

		unless @queued

			throw Error "Track is not queued"

		@queued = no

		loop

			chunk = @_queuedChunks.pop()

			break unless chunk?

			chunk.unqueue()

		return

	shouldUnqueue: (rootT) ->

		localT = @_toLocalT rootT

		if localT > @duration

			return yes

		i = 0

		loop

			chunk = @_queuedChunks[i]

			break unless chunk?

			if chunk.shouldUnqueue localT

				chunk.unqueue()

				@_queuedChunks.shift()

			else

				i++

		@_queueChunksFor localT

		return no