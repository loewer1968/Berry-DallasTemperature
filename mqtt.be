# MQTT helper functions

def mqttDebugLog(message)
  if mqttDebugEnabled == true
    print("MQTT DEBUG - " + str(message))
  end
end

def normalizeTopicRoot(value)
  if value == nil || value == ""
    return "saar159"
  end

  while size(value) > 0 && value[0] == '/'
    value = value[1..size(value)-1]
  end

  while size(value) > 0 && value[size(value)-1] == '/'
    value = value[0..size(value)-2]
  end

  if value == ""
    return "saar159"
  end

  return value
end

def getLocalTimeString()
  try
    var timInfo = tasmota.cmd("status 7")
    var local = timInfo['StatusTIM']['Local']
    if local != nil
      return local
    end
  except ..
  end
  return ""
end

def getTasmotaName()
  if hostname != nil && hostname != ""
    return hostname
  end

  try
    hostname = tasmota.cmd("status 5")['StatusNET']['Hostname']
  except ..
    hostname = "tasmota"
  end

  return hostname
end

def mapDeviceName(device)
  if oneWireDeviceMap == nil
    return
  end

  var id = device.address.tohex()
  var mapping = nil
  try
    mapping = oneWireDeviceMap[id]
  except ..
  end

  if mapping != nil && mapping["device_name"] != nil && mapping["device_name"] != ""
    device.name = mapping["device_name"]
  end
end

def roundMqttValue(value)
  import math
  var factor = 1.0
  var digits = mqttRoundDigits
  while digits > 0
    factor = factor * 10
    digits = digits - 1
  end
  return math.round(value * factor) / factor
end

def mqttPublishPayload(topic, payload)
  import mqtt
  try
    mqttDebugLog("publishing with mqtt.publish topic:" + topic)
    mqtt.publish(topic, payload, true)
    mqttDebugLog("mqtt.publish invoked for topic:" + topic)
    return true
  except .. as exname, exmsg
    mqttDebugLog("mqtt.publish failed topic:" + topic + " ex=" + exname + " msg=" + exmsg)
    return false
  end
end

def publishMqttForDevice(dt, device, roundedValue)
  var tasmotaName = getTasmotaName()
  var pin = str(dt.gpio)
  var sensorId = device.address.tohex()
  var deviceId = sensorId
  var deviceName = device.name
  var mapping = nil
  try
    mapping = oneWireDeviceMap[sensorId]
  except ..
  end

  if mapping != nil
    if mapping["device_id"] != nil && mapping["device_id"] != ""
      deviceId = mapping["device_id"]
    end
    if mapping["device_name"] != nil && mapping["device_name"] != ""
      deviceName = mapping["device_name"]
    end
  end

  var topic = mqttTopicRoot + "/" + deviceId

  var payload = DynClass()
  payload.tasmota_name = tasmotaName
  payload.pin = dt.gpio
  payload.device_id = deviceId
  payload.device_name = deviceName
  payload.sensor_id = sensorId
  payload.value = roundedValue
  payload.offset = device.offset
  payload.timestamp = getLocalTimeString()
  payload.last_measurement = device.lastMeasureAt

  mqttDebugLog("MQTT publish sensor " + deviceId + " from GPIO " + pin + " topic:" + topic)
  return mqttPublishPayload(topic, payload.toJson())
end
