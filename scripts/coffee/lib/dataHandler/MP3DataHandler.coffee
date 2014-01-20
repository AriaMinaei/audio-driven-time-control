mp = require 'mp3-parser'
TrackPiece = require './ChunkData'

module.exports = class MP3DataHandler

	constructor: (@buffer) ->

		@data = new DataView @buffer

		@uint8View = new Uint8Array @buffer

		@_chunksByDuration = {}

		@_boundries = new Uint32Array 1

	_findFrameBoundries: ->

		return @_boundries if @_boundries.length > 1

		frame = @_findFirstFrame()

		boundries = []

		loop

			boundries.push frame._section.offset

			frame = mp.readFrame @data, frame._section.nextFrameIndex

			break unless frame?

		@_boundries = new Uint32Array boundries

	split: (chunkDuration = 10.0, maxChunks = 0) ->

		if @_chunksByDuration[chunkDuration]?

			return @_chunksByDuration[chunkDuration]

		boundries = @_findFrameBoundries()

		firstFrame = @_findFirstFrame()

		samplesPerFrame = firstFrame._section.sampleLength

		eachFrameDuration = firstFrame._section.sampleLength / firstFrame.header.samplingRate

		framesPerChunk = (chunkDuration / eachFrameDuration)|0

		chunks = []

		fromFrame = 0

		isLastChunk = no

		prependFrames = 0

		appendFrames = 0

		loop

			toFrame = fromFrame + framesPerChunk

			if toFrame >= boundries.length

				toFrame = boundries.length

				isLastChunk = yes

			framesToGoBack = prependFrames

			if fromFrame - framesToGoBack < 0 then framesToGoBack = 0

			framesToGoForward = appendFrames

			if framesToGoForward + toFrame > boundries.length

				framesToGoForward = boundries.length - toFrame

			a = @uint8View.subarray boundries[fromFrame - framesToGoBack],

				boundries[toFrame + framesToGoForward]

			newArray = new Uint8Array boundries[toFrame + framesToGoForward] -

				boundries[fromFrame - framesToGoBack]

			newArray.set a

			chunk = new TrackPiece newArray.buffer,

				eachFrameDuration * (toFrame - fromFrame),

				eachFrameDuration * fromFrame,

				eachFrameDuration * framesToGoBack

			console.log 'chunk', chunks.length, 'starts from', eachFrameDuration * fromFrame,

				'goes on for', eachFrameDuration * (toFrame - fromFrame),

				'to', eachFrameDuration * (toFrame - fromFrame) + eachFrameDuration * fromFrame

				'skips', eachFrameDuration * framesToGoBack

			chunks.push chunk

			fromFrame = toFrame

			break if maxChunks > 0 and chunks.length >= maxChunks

			break if isLastChunk

		@_chunksByDuration[chunkDuration] = chunks

		chunks


	_old: ->


		lastChunkLastFrameByteLength = 0


		currentStartIndex = firstFrame._section.offset

		currentByteLength = 0

		currentDuration = 0

		currentStartTime = 0

		frame = firstFrame

		loop

			next =  mp.readFrame @data, frame._section.nextFrameIndex

			currentByteLength += frame._section.byteLength

			frameDuration = frame._section.sampleLength / frame.header.samplingRate

			currentDuration += frameDuration

			if currentDuration >= chunkDuration or not next?

				if chunks.length is 0

					a = @uint8View.subarray currentStartIndex, currentStartIndex + currentByteLength

					newArray = new Uint8Array currentByteLength

					newArray.set a

					chunk = new TrackPiece newArray.buffer, currentDuration, currentStartTime


				else

					a = @uint8View.subarray currentStartIndex - lastChunkLastFrameByteLength, currentStartIndex + currentByteLength

					newArray = new Uint8Array currentByteLength + lastChunkLastFrameByteLength

					newArray.set a

					chunk = new TrackPiece newArray.buffer, currentDuration, currentStartTime, frameDuration

				lastChunkLastFrameByteLength = frame._section.byteLength

				chunks.push chunk

				break if maxPieces > 0 and chunks.length is maxPieces

				currentStartTime += currentDuration
				currentDuration = 0.0

				currentStartIndex += currentByteLength
				currentByteLength = 0

			break unless next?

			frame = next

		@_chunksByDuration[chunkDuration] = chunks

		chunks

	_findFirstFrame: ->

		i = 0

		id3v2 = mp.readId3v2Tag @data

		if id3v2?

			i+= id3v2._section.byteLength

		loop

			i++

			break if i > @data.byteLength

			frame = mp.readFrame @data, i

			continue unless frame?

			return frame

		return

	_extractFrames: ->

