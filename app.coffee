logger = require('graceful-logger').format 'medium'
app = require './src/server'

port = process.env.PORT or 7230

app.listen port, -> logger.info "Talk-services listen on #{port}"
