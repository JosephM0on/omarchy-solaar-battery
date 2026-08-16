// Parse `solaar show` into one entry per device (last Battery line wins).

function parseSolaarShow(raw) {
  var byName = {}
  var order = []
  var current = ""
  var kind = ""
  var lines = String(raw || "").split("\n")

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]

    var child = /^ {2,4}\d+: ([^,{]*)$/.exec(line)
    if (child) {
      current = child[1].trim()
      kind = ""
      continue
    }

    if (/^\S/.test(line) && line.indexOf(":") === -1) {
      var header = line.trim()
      if (header.length > 1 && !/^solaar /i.test(header) && !/receiver/i.test(header)) {
        current = header
        kind = ""
      }
      continue
    }

    var kindLine = /^\s+Kind\s*:\s*(\w+)/.exec(line)
    if (kindLine && kindLine[1] && kindLine[1].toLowerCase() !== "none") {
      kind = kindLine[1].toLowerCase()
      continue
    }

    var parsed = parseBatteryLine(line)
    if (!parsed || !current) continue

    var name = current
    if (!byName[name]) order.push(name)
    byName[name] = {
      name: name,
      shortName: shortName(name),
      kind: inferKind(kind, name),
      percent: parsed.percent,
      millivolt: parsed.millivolt,
      status: parsed.status
    }
  }

  var devices = []
  for (var j = 0; j < order.length; j++) devices.push(byName[order[j]])
  return devices
}

function parseBatteryLine(line) {
  var withMv = /^\s*Battery:\s*(\d+)%\s+(\d+)mV\s*,\s*BatteryStatus\.(\w+)\.\s*$/.exec(line)
  if (withMv) {
    return {
      percent: parseInt(withMv[1], 10),
      millivolt: parseInt(withMv[2], 10),
      status: withMv[3]
    }
  }

  var noMv = /^\s*Battery:\s*(\d+)%,\s*BatteryStatus\.(\w+)\.\s*$/.exec(line)
  if (noMv) {
    return {
      percent: parseInt(noMv[1], 10),
      millivolt: null,
      status: noMv[2]
    }
  }

  return null
}

// Solaar maps 4.2V=100% and 3.5V=0%. The G733 charge controller tops out
// near 4.0V, so a full headset never reads past ~80% on that table.
function correctedPercent(millivolt, fullMv, emptyMv) {
  if (millivolt === null || millivolt === undefined || isNaN(millivolt)) return null
  var p = Math.round((millivolt - emptyMv) / (fullMv - emptyMv) * 100)
  return Math.max(0, Math.min(100, p))
}

function shouldCorrectVoltage(device) {
  return !!(device && /g733/i.test(device.name || "") && device.millivolt != null)
}

function displayPercent(device) {
  if (!device) return 0
  if (shouldCorrectVoltage(device)) {
    var corrected = correctedPercent(device.millivolt, 4000, 3500)
    if (corrected !== null) return corrected
  }
  return device.percent
}

function inferKind(kind, name) {
  var k = String(kind || "").toLowerCase()
  if (k === "keyboard" || k === "mouse" || k === "headset") return k
  var n = String(name || "").toLowerCase()
  if (n.indexOf("keyboard") !== -1) return "keyboard"
  if (n.indexOf("mouse") !== -1 || n.indexOf("pro x") !== -1) return "mouse"
  if (n.indexOf("headset") !== -1 || n.indexOf("headphone") !== -1 || n.indexOf("g733") !== -1)
    return "headset"
  return "unknown"
}

function shortName(name) {
  var n = String(name || "").trim()
  if (/G915/i.test(n)) return "G915 TKL"
  if (/PRO X/i.test(n)) return "PRO X"
  if (/G733/i.test(n)) return "G733"
  var stripped = n.replace(/\s+(LIGHTSPEED|Wireless|RGB|Mechanical|Gaming|Keyboard|Mouse|Headset).*$/i, "").trim()
  return stripped || n
}

function deviceIcon(kind) {
  if (kind === "keyboard") return "󰌌"
  if (kind === "mouse") return "󰍽"
  if (kind === "headset") return "󰋋"
  return "󰁹"
}

function isLow(device) {
  var percent = displayPercent(device)
  var status = String((device && device.status) || "").toUpperCase()
  if (status === "RECHARGING" || status === "FULL") return false
  return percent <= 20
}

function formatLabel(devices, vertical) {
  var list = Array.isArray(devices) ? devices : []
  if (list.length === 0) return ""

  if (vertical) {
    var lowest = list[0]
    for (var i = 1; i < list.length; i++) {
      if (displayPercent(list[i]) < displayPercent(lowest)) lowest = list[i]
    }
    return deviceIcon(lowest.kind) + "\n" + displayPercent(lowest) + "%"
  }

  var parts = []
  for (var j = 0; j < list.length; j++) {
    parts.push(deviceIcon(list[j].kind) + " " + displayPercent(list[j]) + "%")
  }
  return parts.join("  ")
}

function formatTooltip(devices) {
  var list = Array.isArray(devices) ? devices : []
  if (list.length === 0) return "No Logitech battery devices"
  var lines = []
  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    var line = d.shortName + "  " + displayPercent(d) + "%"
    if (shouldCorrectVoltage(d)) line += "  (Solaar " + d.percent + "%)"
    if (d.millivolt != null) line += "  " + d.millivolt + " mV"
    if (d.status) line += "  " + String(d.status).toLowerCase()
    lines.push(line)
  }
  return lines.join("\n")
}

function anyLow(devices) {
  var list = Array.isArray(devices) ? devices : []
  for (var i = 0; i < list.length; i++) {
    if (isLow(list[i])) return true
  }
  return false
}

function isCharging(device) {
  var s = String((device && device.status) || "").toUpperCase()
  return s === "RECHARGING" || s === "CHARGING"
}

function lowestDevice(devices) {
  var list = Array.isArray(devices) ? devices : []
  if (list.length === 0) return null
  var lowest = list[0]
  for (var i = 1; i < list.length; i++) {
    if (displayPercent(list[i]) < displayPercent(lowest)) lowest = list[i]
  }
  return lowest
}

function anyCharging(devices) {
  var list = Array.isArray(devices) ? devices : []
  for (var i = 0; i < list.length; i++) {
    if (isCharging(list[i])) return true
  }
  return false
}

function batteryIcon(percent, charging) {
  var chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
  var defaultIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  var index = Math.max(0, Math.min(9, Math.floor(Number(percent) / 10)))
  return charging ? chargingIcons[index] : defaultIcons[index]
}

function barBatteryIcon(devices) {
  var lowest = lowestDevice(devices)
  if (!lowest) return "󰁹"
  return batteryIcon(displayPercent(lowest), anyCharging(devices))
}

function kindLabel(kind) {
  if (kind === "keyboard") return "Keyboard"
  if (kind === "mouse") return "Mouse"
  if (kind === "headset") return "Headset"
  return "Device"
}

function statusLabel(status) {
  var s = String(status || "").toLowerCase().replace(/_/g, " ")
  return s
}
