service = require '../service'

_receiveWebhook = ({integration, body}) ->
  payload = body?.payload

  try
    if toString.call(payload) is '[object String]'
      payload = JSON.parse payload
    return false unless toString.call(payload) is '[object Object]'
  catch err
    return false

  throw new Error('Params missing') unless payload.status_message

  title = "[#{payload.status_message}] " +
          "#{payload.repository?.name} ##{payload.number} " +
          "(#{payload.branch} - #{payload.commit[0...7]}) by #{payload.author_name}"

  message =
    integration: integration
    attachments: [
      category: 'quote'
      data:
        title: title
        text: payload.message
        redirectUrl: payload.build_url
    ]

  @sendMessage message

module.exports = service.register 'travis', ->

  @title = 'Travis CI'

  @template = 'webhook'

  @summary = service.i18n
    zh: '分布式持续集成服务'
    en: 'A distributed continuous integration service.'

  @description = service.i18n
    zh: 'Travis CI 是一个在线的，分布式的持续集成服务，用来构建及测试在 GitHub 托管的代码。'
    en: 'Travis CI is a distributed continuous integration service.'

  @iconUrl = service.static 'images/icons/travis@2x.png'

  @_fields.push
    key: 'webhookUrl'
    type: 'text'
    readonly: true
    description: service.i18n
      zh: '复制 web hook 地址到 .travis.yml 中使用。'
      en: 'Copy this web hook to your .travis.yml to use it.'

  @registerEvent 'service.webhook', _receiveWebhook
