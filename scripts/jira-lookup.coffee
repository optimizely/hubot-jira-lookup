# Description:
#   Jira lookup when issues are heard
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JIRA_LOOKUP_USERNAME
#   HUBOT_JIRA_LOOKUP_PASSWORD
#   HUBOT_JIRA_LOOKUP_URL
#   HUBOT_JIRA_LOOKUP_IGNORE_USERS (optional, format: "user1|user2", default is "jira|github")
#   HUBOT_JIRA_LOOKUP_SIMPLE
#
# Commands:
#   None
#
# Author:
#   Matthew Finlayson <matthew.finlayson@jivesoftware.com> (http://www.jivesoftware.com)
#   Benjamin Sherman  <benjamin@jivesoftware.com> (http://www.jivesoftware.com)
#   Dustin Miller <dustin@sharepointexperts.com> (http://sharepointexperience.com)

module.exports = (robot) ->

  ignored_users = process.env.HUBOT_JIRA_LOOKUP_IGNORE_USERS
  ignored_user_ids = process.env.HUBOT_JIRA_LOOKUP_IGNORE_USER_IDS
  if ignored_users == undefined
    ignored_users = "jira|github"

  console.log "Ignoring Users: #{ignored_users} User IDs: #{ignored_user_ids}"

  robot.hear /\b[a-zA-Z0-9]{2,12}-[0-9]{1,10}\b/, (msg) ->

    return if msg.message.user.name.match(new RegExp(ignored_users, "gi"))
    return if ignored_user_ids && msg.message.user.id.match(new RegExp(ignored_user_ids, "gi"))

    issue = msg.match[0]

    if process.env.HUBOT_JIRA_LOOKUP_SIMPLE is "true"
      msg.send "Issue: #{issue} - #{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{issue}"
    else
      user = process.env.HUBOT_JIRA_LOOKUP_USERNAME
      pass = process.env.HUBOT_JIRA_LOOKUP_PASSWORD
      url = process.env.HUBOT_JIRA_LOOKUP_URL

      auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')

      robot.http("#{url}/rest/api/latest/issue/#{issue}")
        .headers(Authorization: auth, Accept: 'application/json')
        .get() (err, res, body) ->
          try
            json = JSON.parse(body)

            data = {
              'key': {
                key: 'Key'
                value: issue
              }
              'summary': {
                key: 'Summary'
                value: json.fields.summary || null
              }
              'link': {
                key: 'Link'
                value: "#{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key}"
              }
              'description': {
                key: 'Description',
                value: json.fields.description || null
              }
              'assignee': {
                key: 'Assignee',
                value: (json.fields.assignee && json.fields.assignee.displayName) || 'Unassigned'
              }
              'reporter': {
                key: 'Reporter',
                value: (json.fields.reporter && json.fields.reporter.displayName) || null
              }
              'created': {
                key: 'Created',
                value: json.fields.created && (new Date(json.fields.created)).toLocaleString() || null
              }
              'status': {
                key: 'Status',
                value: (json.fields.status && json.fields.status.name) || null
              }
            }

            fallback = "Issue:\t #{data.key.value}: #{data.summary.value}\n"
            if data.description.value?
              fallback += "Description:\t #{data.description.value}\n"
            fallback += "Assignee:\t #{data.assignee.key}\nStatus:\t #{data.status.value}\nLink:\t #{data.link.value}\n"

            msg.send({
              attachments: [
                {
                  fallback: fallback
                  title: "#{data.key.value}: #{data.summary.value}"
                  title_link: data.link.value
                  text: data.description.value
                  fields: [
                    {
                      title: data.reporter.key
                      value: data.reporter.value
                      short: true
                    }
                    {
                      title: data.assignee.key
                      value: data.assignee.value
                      short: true
                    }
                    {
                      title: data.status.key
                      value: data.status.value
                      short: true
                    }
                    {
                      title: data.created.key
                      value: data.created.value
                      short: true
                    }
                  ]
                }
              ]
            })
          catch error
            console.log error
