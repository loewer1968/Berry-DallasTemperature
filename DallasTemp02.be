# --- this script is processed, after components are created

# ========== DallasTemp ==========

if dallasTemps != nil
  for oldDallas : dallasTemps
    try
      oldDallas.deinit()
    except .. as exname, exmsg
      print("WARN DallasTemp02.init - old instance deinit failed:",exname,exmsg)
    end
  end
end

if oneWirePins == nil
  oneWirePins = [gpioForOneWire]
end

if mqttDebugEnabled == nil
  mqttDebugEnabled = false
end

if mqttRoundDigits == nil || mqttRoundDigits < 0
  mqttRoundDigits = 1
end

if mqttRoundDigits > 6
  mqttRoundDigits = 6
end

if mqttForcePublishIntervalSec == nil || mqttForcePublishIntervalSec <= 0
  mqttForcePublishIntervalSec = 600
end

mqttTopicRoot = normalizeTopicRoot(mqttTopicRoot)

if oneWireDeviceMap == nil
  oneWireDeviceMap = {}
end

var effectivePins = []
for pin : oneWirePins
  if pin != nil
    effectivePins.push(pin)
    if size(effectivePins) >= 8
      break
    end
  end
end

if size(effectivePins) == 0
  effectivePins.push(gpioForOneWire)
end

dallasTemps = []
dallasTemp = nil
var mqttPublishCount = {}
var mqttLastPublishAt = {}
var mqttPublishedValues = {}
var mqttLastPublishMs = {}
var seenPins = {}

for i:0..size(effectivePins)-1
  var pin = effectivePins[i]
  var pinKey = str(pin)

  if seenPins.contains(pinKey)
    print("WARN DallasTemp02.init - duplicate pin ignored:",pinKey)
    continue
  end
  seenPins[pinKey] = true

  mqttPublishCount[pinKey] = 0
  mqttLastPublishAt[pinKey] = "-"

  var groupName = string.format("OneWire.Group.%02d",i+1)
  var dt = DallasTemp(groupName,pin)
  dt.infoEnable = true
  dt.enableSensorMsg = true
  dt.webArgPrefix = string.format("owtemp_%d",pin)
  dt.enabled = true
  dt.startScan()

  dt.onCollectingDone = def (obj)
    var pinKey = str(obj.gpio)
    for device: obj.devices
      mapDeviceName(device)
      if device.value != nil
        var sensorKey = pinKey + ":" + device.address.tohex()
        var roundedValue = roundMqttValue(device.value)
        var shouldPublish = !mqttPublishedValues.contains(sensorKey)

        if !shouldPublish
          if mqttPublishedValues[sensorKey] != roundedValue
            shouldPublish = true
          else
            var lastPublishMs = mqttLastPublishMs[sensorKey]
            if lastPublishMs == nil || tasmota.millis() - lastPublishMs >= mqttForcePublishIntervalSec * 1000
              shouldPublish = true
            end
          end
        end

        if shouldPublish && publishMqttForDevice(obj, device, roundedValue)
          mqttPublishedValues[sensorKey] = roundedValue
          mqttLastPublishMs[sensorKey] = tasmota.millis()
          mqttPublishCount[pinKey] = mqttPublishCount[pinKey] + 1
          mqttLastPublishAt[pinKey] = getLocalTimeString()
        end
      end
    end
  end

  dallasTemps.push(dt)

  if dallasTemp == nil
    dallasTemp = dt
  end
end

if dallasTemp != nil
  dallasTemp.onBuildWebView =
  def()
    var html = ""
    var renderedPins = {}
    var row = '<tr><td><span>%s</span></td><td><span>%s</span></td><td><span>%s</span></td><td><span>%s</span></td><td><span>%s</span></td><td><span>%s</span></td><td><span>%s</span></td></tr>'

    for dt : dallasTemps
      var dimension = dt.useFahrenheit ? "°F" : "°C"
      var pin = str(dt.gpio)
      if renderedPins.contains(pin)
        continue
      end
      renderedPins[pin] = true

      var prefix = dt.webArgPrefix
      var state = dt.enabled ? "enabled" : "disabled"
      var pcount = mqttPublishCount[pin]
      var plast = mqttLastPublishAt[pin]

      var rows = string.format('<tr><td><span>State</span></td><td><span>GPIO %s</span></td><td><span>-</span></td><td><span>-</span></td><td><span>%s</span></td><td><span>MQTT:%d</span></td><td><span>%s</span></td></tr>',pin,state,pcount,plast)

      for device : dt.devices
        mapDeviceName(device)

        var valueText = ""
        if device.value != nil
          valueText = string.format("%5.2f",device.value)
        end

        rows += string.format(row,
            device.name,
            str(device.address.tohex()),
            str(device.isFake()),
            str(device.offset),
            device.hasError ? "no" : "yes",
            valueText,
            device.lastMeasureAt)
      end

      rows += string.format('<tr><td><button id=%s_scan onclick=dola(this)>Scan GPIO %s</button></td><td><button id=%s_clear onclick=dola(this)>Clear list</button></td><td><button id=%s_enable onclick=dola(this)>Enable</button></td><td><button id=%s_disable onclick=dola(this)>Disable</button></td><td></td><td></td><td></td></tr>',prefix,pin,prefix,prefix,prefix)

      html += string.format('<table class=berry><tbody><tr><th colspan=7>Temperatures GPIO %s</th></tr><tr><th>Name</th><th>Address</th><th>Is Fake</th><th>Offset [%s]</th><th>Valid</th><th>Value [%s]</th><th>Value time</th></tr>%s</tbody></table>',pin,dimension,dimension,rows)
    end

    return html
  end
end

# ========== !!Thingspeak !!==========
# uncomment following area to test the ThingSpeak-component

#- 
# create an instance
thingSpeak = ThingSpeak()

# let us see the logs
thingSpeak.infoEnable=true

# !!! put here the 'Write Api KEY' from ThingSpeak 
thingSpeak.apiKey="your-api-key"

# limit the data-rate
thingSpeak.updatesPerHour(60)

# use the callback of dallasTemp fired, when all sensors are acquired
dallasTemp.onCollectingDone=def (dallasTemp)
end
-#


