Cylon = require '../..'

Cylon.robot
  connections: [
    {name: 'digispark', adaptor: 'digispark'},
    {name: 'leapmotion', adaptor: 'leapmotion', port: '127.0.0.1:6437'}
  ]

  devices: [
    {name: 'servo1', driver: 'servo', pin: 0, connection: 'digispark'},
    {name: 'servo2', driver: 'servo', pin: 1, connection: 'digispark'},
    {name: 'leapmotion', driver: 'leapmotion', connection: 'leapmotion'}
  ]

  work: (my) ->
    my['x'] = 90
    my['z'] = 90

    my.leapmotion.on 'hand', (hand) ->
      my['x'] = hand.palmX.fromScale(-300, 300).toScale(30, 150)
      my['z'] = hand.palmZ.fromScale(-300, 300).toScale(30, 150)

    every 100, ->
      my.servo1.angle my['x']
      my.servo2.angle my['z']

      console.log "Current Angle: #{my.servo1.currentAngle()}, #{my.servo2.currentAngle()}"

.start()
