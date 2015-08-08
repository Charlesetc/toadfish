log = console.log
express = require('express')
util = require('../lib/util')
mongoose = require('mongoose')
Room = require('../models/room')
Update = require('../models/update')
router = express.Router()

router.get "/", (req, res) ->
  Room.find {hostSessionID: req.sessionID}, (err, rooms) ->
    res.render "launch", {title: "Toadfish", rooms: rooms, layout: "views/layout.toffee"}

router.get "/demo", (req, res) ->
  res.render "room", {
    title: "Toadfish", 
    host: false,
    roomID: "", 
    playlistSettings: {}, 
    layout: "views/layout.toffee"
  }

router.post "/createRoom", (req, res) ->
  db = req.db
  sessionID = req.sessionID
  roomName = req.body.roomName
  checkAndCreate = () ->
    roomID = if roomName != "" then util.encodeHtml(roomName).split(' ').join('-') else Math.random().toString(36).substr(2, 7)
    Room.find {roomID: roomID}, (err, rooms) ->
      if (rooms.length > 0)
        if (roomName != "")
          return res.send {
            alreadyExists: true
          }
        else
          return checkAndCreate()
      Room.create { roomName: req.body.roomName, roomID:  roomID, hostSessionID: sessionID, update: new Date()}, (err, newRoom) ->
        if (err)
          console.error "Error creating room: " + JSON.stringify(err)
          res.status(500).send err
        else
          return res.send {
            roomID: roomID,
            alreadyExists: false
          }
  checkAndCreate()

router.post "/savePlaylist", (req, res) ->
  Room.findOne {$and: [{roomID: req.body.roomID}, {hostSessionID: req.sessionID}]}, (err, room) ->
    if (err)
      console.error "Error finding room to save to: " + JSON.stringify(err)
      return res.status(500).end()
    if (!room)
      console.error "No room " + req.body.roomID + " with sessionID " + req.sessionID + " exists"
      return res.status(500).end()
    playlistSettings = JSON.parse(req.body.playlistSettings)
    room.playlistSettings.currentIndex = JSON.parse(playlistSettings.currentIndex) if playlistSettings.currentIndex
    room.playlistSettings.playlist = JSON.stringify(playlistSettings.playlist) if playlistSettings.playlist
    room.playlistSettings.volume = JSON.parse(playlistSettings.volume) if playlistSettings.volume
    room.playlistSettings.state = JSON.parse(playlistSettings.state) if playlistSettings.state
    room.playlistSettings.autoplay = JSON.stringify(playlistSettings.autoplay) if playlistSettings.autoplay
    room.playlistSettings.lastRdioStation = playlistSettings.lastRdioStation if playlistSettings.lastRdioStation
    room.update = new Date()
    room.save (err) ->
      if (err)
        console.error "Error saving playlist: " + JSON.stringify(err)
        return res.status(500).end()
      res.status(200).end()

router.post "/sendUpdate", (req, res) ->
  Update.create { roomID: req.body.roomID, type:  req.body.type, data: req.body.data, host: req.body.host}, (err, newUpdate) ->
    if (err)
      console.error "Error creating update: " + JSON.stringify(err)
      res.status(500).send err
    else
      return res.status(200).end()

router.get "/host/:roomID", (req, res) ->
  roomID = req.param("roomID")
  Room.findOne {roomID: roomID}, (err, room) ->
    if (err)
      console.error "Error finding room: " + JSON.stringify(err)
      return res.status(500).end()
    if (!room)
      return res.status(404).end()
    if (room.hostSessionID != req.sessionID)
      return res.redirect '/' + roomID

    room.update = new Date()
    room.save 
    
    res.render "host-room", {
      title: "Toadfish - " + roomID, 
      host: true,
      roomID: roomID,
      roomName: room.roomName || "Toadfish Room",
      playlistSettings: room.playlistSettings, 
      layout: "views/layout.toffee"
    }

router.get "/:roomID", (req, res) ->
  roomID = req.param("roomID")
  Room.findOne {roomID: roomID}, (err, room) ->
    if (err)
      console.error "Error finding room: " + JSON.stringify(err)
      return res.status(500).send err
    if (!room)
      return res.status(404).end() #render lost page
    if (room.hostSessionID == req.sessionID)
      return res.redirect '/host/' + roomID

    room.update = new Date()
    room.save 
    
    res.render "basic-room", {
      title: "Toadfish - " + roomID, 
      host: false,
      roomID: roomID, 
      roomName: room.roomName || "Toadfish Room",
      playlistSettings: room.playlistSettings, 
      layout: "views/layout.toffee"
    }

router.post "/error", (req, res) ->
  console.error req.body.msg
  res.status(200).send("Error Logged")

module.exports = router
