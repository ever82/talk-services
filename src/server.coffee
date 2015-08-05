express = require 'express'
morgan = require 'morgan'
bodyParser = require 'body-parser'

app = express()
app.use morgan morgan.tiny
app.use bodyParser.json limit: '10mb'
app.use bodyParser.urlencoded extended: true, limit: '10mb'

module.exports = app

service = require './service'
