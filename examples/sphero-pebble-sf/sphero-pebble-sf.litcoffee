# Sphero Pebble Sales Force
    
First, let's import Cylon:

    Cylon = require '../..'

Next up, we'll configure the API Cylon will serve, telling it to serve on port
`8080`.    

    Cylon.api host: '0.0.0.0', port: '8080'

Now that we have Cylon imported, we can start defining our pebble robot

    class PebbleRobot

Let's define the connections and devices:

      connection: { name: 'pebble', adaptor: 'pebble' }
      device: { name: 'pebble', driver: 'pebble' }

      message: (robot, msg) =>
        robot.message_queue().push(msg)

Now that Cylon knows about the necessary hardware we're going to be using, we'll
tell it what work we want to do:

      work: (me) ->
        me.pebble.on 'connect', -> console.log "Connected!"

Let's define our Sales Force robot

    class SalesforceRobot

Let's define the connections and devices:

      connection:
        name: 'sfcon'
        adaptor: 'force'
        sfuser: process.env.SF_USERNAME
        sfpass: process.env.SF_SECURITY_TOKEN
        orgCreds:
          clientId: process.env.SF_CLIENT_ID
          clientSecret: process.env.SF_CLIENT_SECRET
          redirectUri: 'http://localhost:3000/oauth/_callback'

      device: { name: 'salesforce', driver: 'force' }

      spheroReport: {}

Tell it what work we want to do:

      work: (me) ->
        me.salesforce.on 'start', () ->
          me.salesforce.subscribe '/topic/SpheroMsgOutbound', (data) ->
            name = data.sobject.Sphero_Name__c
            bucks = data.sobject.Bucks__c

            msg = "Sphero: #{name},"
            msg += "data Bucks: #{bucks},"
            msg += "SM_Id: #{data.sobject.Id}"

            console.log msg

            me.master.findRobot name, (err, spheroBot) ->
              spheroBot.react spheroBot.devices.sphero

            me.spheroReport[name] = bucks

            toPebble = ""
            toPebble += "#{key}: $#{val}\n" for key, val of me.spheroReport

            me.master.findRobot 'pebble', (error, pebbleBot) ->
              pebbleBot.message pebbleBot.devices.pebble, toPebble

Let's define our Sphero robot

    class SpheroRobot
      totalBucks: 1
      payingPower: true

      connection: { name: 'sphero', adaptor: 'sphero' }

      device: { name: 'sphero', driver: 'sphero' }

      react: (device) ->
        device.setRGB 0x00FF00
        device.roll 90, Math.floor(Math.random() * 360)
        @payingPower = true

      bankrupt: () ->
        every 3.seconds(), () =>
          if @payingPower and @totalBucks > 0
            @totalBucks += -1
            if @totalBucks is 0
              @sphero.setRGB 0xFF000
              @sphero.stop()

      changeDirection: () ->
        every 1.seconds(), () =>
          @sphero.roll 90, Math.floor(Math.random() * 360) if @payingPower

Tell it what work we want to do:

      work: (me) ->

        me.sphero.on 'connect', ->
          console.log 'Setting up Collision Detection...'
          me.sphero.detectCollisions()
          me.sphero.stop()
          me.sphero.setRGB 0x00FF00
          me.sphero.roll 90, Math.floor(Math.random() * 360)
          me.bankrupt()
          me.changeDirection()

        me.sphero.on 'collision', (data) ->
          me.sphero.setRGB 0x0000FF
          me.sphero.stop()
          me.payingPower = false

          data = JSON.stringify
            spheroName: "#{me.name}",
            bucks: "#{me.totalBucks++}"

          me.master.findRobot 'salesforce', (err, sf) ->
            sf.devices.salesforce.push "SpheroController", "POST", data

    salesforceRobot = new SalesforceRobot()
    salesforceRobot.name = "salesforce"
    Cylon.robot salesforceRobot

    pebbleRobot = new PebbleRobot()
    pebbleRobot.name = "pebble"
    Cylon.robot pebbleRobot

    bots = [
      { port: '/dev/tty.Sphero-ROY-AMP-SPP', name: 'ROY' },
      { port: '/dev/tty.Sphero-GBO-AMP-SPP', name: 'GBO'},
      { port: '/dev/tty.Sphero-RRY-AMP-SPP', name: 'RRY'}
    ]

    for bot in bots
      robot = new SpheroRobot
      robot.connection.port = bot.port
      robot.name = bot.name
      Cylon.robot robot

Now that our robot knows what work to do, and the work it will be doing that
hardware with, we can start it:

    Cylon.start()
