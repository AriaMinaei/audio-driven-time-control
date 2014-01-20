mp = require 'mp3-parser'
TrackPiece = require './ChunkData'

module.exports = class MP3DataHandler

	constructor: (@buffer) ->

		@data = new DataView @buffer

		@uint8View = new Uint8Array @buffer

		@_chunksByDuration = {}

	split: (chunkDuration = 10.0, maxPieces = 0) ->

		if @_chunksByDuration[chunkDuration]?

			return @_chunksByDuration[chunkDuration]

		firstFrame = @_findFirstFrame()

		chunks = []

		lastChunkLastFrameByteLength = 0

		samplesPerFrame = firstFrame._section.sampleLength

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

