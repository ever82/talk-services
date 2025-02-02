moment = require 'moment-timezone'
marked = require 'marked'
service = require '../service'

_receiveWebhook = ({integration, body, headers}) ->
  payload = body
  event = headers["x-coding-event"]

  # When the token of integration is settled
  # Compare it with the payload.token
  if integration.token and integration.token isnt payload.token
    throw new Error("Invalid token of coding")

  message = integration: integration
  attachment = category: 'quote', data: {}

  projectName = if payload.repository?.name then "[#{payload.repository.name}] " else ''
  projectUrl = payload.repository?.web_url
  authorName = if payload.author?.name then "#{payload.author.name} " else ''

  switch event
    when 'push'
      # Prepare to send the message
      if payload.before?[...6] is '000000'
        attachment.data.title = "#{projectName}新建了分支 #{payload.ref}"
      else if payload.after?[...6] is '000000'
        attachment.data.title = "#{projectName}删除了分支 #{payload.ref}"
      else
        attachment.data.title = "#{projectName}提交了新的代码"
        if payload.commits?.length
          commitArr = payload.commits.map (commit) ->
            commitUrl = "#{projectUrl}/git/commit/#{commit.sha}"
            """
            <a href="#{commitUrl}" target="_blank"><code>#{commit.sha[...6]}:</code></a> #{commit.short_message}<br>
            """
          text = commitArr.join ''
          attachment.data.text = text
      attachment.data.redirectUrl = projectUrl

    when 'member'
      switch payload.action
        when 'create'
          attachment.data.title = "#{projectName}#{authorName}添加了新的成员 #{payload.target_user.name}"
          attachment.data.redirectUrl = "#{projectUrl}/members/#{payload.target_user.global_key}"
        else return false

    when 'task'
      attachment.data.redirectUrl = "#{projectUrl}/tasks"
      switch payload.action
        when 'create'
          attachment.data.title = "#{projectName}#{authorName}添加了新的任务 #{payload.task.content}"
        when 'update_deadline'
          attachment.data.title = "#{projectName}#{authorName}更新了任务 #{payload.task.content} 的截止日期 #{moment(payload.task.deadline).tz('Asia/Shanghai').format('YYYY-MM-DD')}"
        when 'update_priority'
          prioritys = ['有空再看', '正常处理', '优先处理', '十万火急']
          attachment.data.title = "#{projectName}#{authorName}更新了任务 #{payload.task.content} 的优先级 #{prioritys[payload.task.priority] or ''}"
        when 'reassign'
          attachment.data.title = "#{projectName}#{authorName}将任务 #{payload.task.content} 指派给 #{payload.task.owner.name}"
        when 'finish'
          attachment.data.title = "#{projectName}#{authorName}完成了任务 #{payload.task.content}"
        when 'restore'
          attachment.data.title = "#{projectName}#{authorName}重做了任务 #{payload.task.content}"
        else return false

    when 'topic'
      attachment.data.redirectUrl = payload.topic.web_url
      switch payload.action
        when 'create'
          attachment.data.title = "#{projectName}#{payload.topic.author.name} 发起了新的话题 #{payload.topic.title}"
        when 'update'
          attachment.data.title = "#{projectName}#{payload.topic.author.name} 更新了话题 #{payload.topic.title}"
        else return false

    when 'document'
      attachment.data.redirectUrl = payload.document.web_url
      targetTypes =
        dir: '文件夹'
        file: '文件'
      switch payload.action
        when 'create'
          attachment.data.title = "#{projectName}#{authorName}创建了新的#{targetTypes[payload.type] or '文件'} #{payload.document.name}"
        when 'upload'
          attachment.data.title = "#{projectName}#{authorName}上传了新的#{targetTypes[payload.type] or '文件'} #{payload.document.name}"
        when 'update'
          attachment.data.title = "#{projectName}#{authorName}更新了#{targetTypes[payload.type] or '文件'} #{payload.document.name}"
        else return false

    when 'watch'
      attachment.data.redirectUrl = projectUrl
      switch payload.action
        when 'watch'
          attachment.data.title = "#{projectName}#{authorName}关注了项目"
        else return false

    when 'star'
      attachment.data.redirectUrl = projectUrl
      switch payload.action
        when 'star'
          attachment.data.title = "#{projectName}#{authorName}收藏了项目"
        else return false

    when 'merge_request', 'pull_request'
      attachment.data.redirectUrl = payload[event].web_url
      switch payload[event]?.action
        when 'create'
          attachment.data.title = "#{projectName}新的 #{event} 请求 #{payload[event].title}"
          attachment.data.text = marked(payload[event].body) if payload[event].body
        when 'refuse'
          attachment.data.title = "#{projectName}拒绝了 #{event} 请求 #{payload[event].title}"
          attachment.data.text = marked(payload[event].body) if payload[event].body
        when 'merge'
          attachment.data.title = "#{projectName}合并了 #{event} 请求 #{payload[event].title}"
          attachment.data.text = marked(payload[event].body) if payload[event].body
        else return false

    else return false

  message.attachments = [attachment]
  @sendMessage message

# Register the coding service
module.exports = service.register 'coding', ->

  @title = 'Coding.net'

  @template = 'webhook'

  @summary = service.i18n
    en: 'Coding.net is a developer-oriented cloud development platform, provides a running space, quality control, providing code hosting, project management, and other functions.'
    zh: '面向开发者的云端开发平台。'

  @description = service.i18n
    en: "Coding.net is a developer-oriented cloud development platform, provides a running space, quality control, providing code hosting, project management, and other functions. When you Git version of the repository on the Coding.net when there is a new Push, you'll catch up on Talk received this Push on and information about the repository."
    zh: 'Coding.net 是面向开发者的云端开发平台，提供了提供代码托管、运行空间、质量控制、项目管理等功能。当您在 Coding.net 上的 Git 版本仓库有新的 Push 的时候，你会在简聊上收到本次 Push 以及本仓库的相关信息。'

  @iconUrl = service.static 'images/icons/coding@2x.png'

  @_fields.push
    key: 'webhookUrl'
    type: 'text'
    readOnly: true
    description: service.i18n
      zh: '进入你的 Coding.net 项目设置，选择 WebHook 设置，添加 WebHook 地址到项目中即可接收推送通知。'
      en: 'Open your project settings on Coding.net, select the WebHook settings, add a WebHook address to your project to receive push notifications.'

  @registerEvent 'service.webhook', _receiveWebhook
