mod = angular.module("myApp", ["ngRoute"])


mod.config ($routeProvider)->
  $routeProvider
    .when "/",
      templateUrl: "views/main.html",
      controller: "mainCtrl"
    .when "/charts/:id",
      templateUrl: "views/charts.html",
      controller: "chartCtrl"

mod.controller "mainCtrl", ($scope) ->
  $scope.chartsList = {
    firstchart: "t.http.POST-notifier_api-v1-notices",
    secondChart: "t.http.POST-notifier_api-v2-notices",
    thirdChart: "t.http.POST-notifier_api-v3-notices"
  }

mod.controller "chartCtrl", ($scope, chartsData, $routeParams) ->
  $scope.scales = {
    year: {
      name: "Year",
      convertRatio: 3,
      requestingResolution: "year", 
      time: 31536000000,
      condition: true
    },
    threeMonth: {
      name: "Three month",
      convertRatio: 2,
      requestingResolution: "year", 
      time: 7776000000,
      condition: true
    },
    month: {
      name: "Month",
      convertRatio: 2,
      requestingResolution: "year", 
      time: 2592000000,
      condition: true
    },
    week: {
      name: "Week",
      convertRatio: 1,
      requestingResolution: "year", 
      time: 604800000,
      condition: true
    },
    day: {
      name: "Day",
      convertRatio: 3,
      requestingResolution: "day", 
      time: 86400000,
      condition: true
    },
    hour: {
      name: "Hour",
      convertRatio: 1,
      requestingResolution: "day", 
      time: 3600000,
      condition: true
    },
  }
  
  $scope.scalesList = ["year", "threeMonth", "month", "week", "day", "hour"];

  chartsInfo = [
    {
      name: "n",
      yAxeLabel: {day: "RPM", year: "RPH"},
      lineNames :["n"]
    },
    {
      name: "meanStddev",
      yAxeLabel: {day: "ms", year: "ms"},
      lineNames: ["mean", "stddev"]
      } ,
    {
      name: "max",
      yAxeLabel: {day: "ms", year: "ms"},
      lineNames: ["max"]
      },
    {
      name: "min",
      yAxeLabel: {day: "ms", year: "ms"},
      lineNames: ["min"]
    }
  ]

  $scope.id = $routeParams.id


  refreshCharts = () ->
    getData


  reformData = (currentScale) ->
    console.log "reformData"
    chartsData.getData($scope.resolution, $scope.id)
    .then (data) ->
      $scope.charts = {}
      for chartInfo in chartsInfo
        $scope.charts[chartInfo.name] = getChart(data, chartInfo, $scope.id, $scope.resolution, $scope.scales[currentScale])

      points =  $scope.charts[chartInfo.name].line[0].data
      $scope.defaultResolution = getXAxeRange(points)
      $scope.visibleRange = getVisibleRange($scope.defaultResolution, $scope.scales[currentScale]["time"])
      redrawCharts()
    .then () ->
      updateInterval = 2000
      setTimeout( () -> 
        reformData($scope.currentScale)
      , updateInterval)
    , (errorMessage) ->
      $scope.error = errorMessage

  $scope.setResolution = (currentScale)->
    $scope.currentScale = currentScale
    newConvertRatio = $scope.scales[currentScale]["convertRatio"]
    newResolution = $scope.scales[currentScale]["requestingResolution"]
    
    for scale in $scope.scalesList
      $scope. scales[scale].condition = false
      if (scale == currentScale)
        $scope. scales[scale].condition = true
    
    if ($scope.resolution == newResolution) && ($scope.convertRatio == newConvertRatio)
      $scope.visibleRange = getVisibleRange($scope.defaultResolution, $scope.scales[currentScale]["time"])
      redrawCharts()
    else
      $scope.resolution = newResolution
      $scope.convertRatio = newConvertRatio
      reformData(currentScale)

  $scope.setResolution("day")

  redrawCharts = ()->
    for chartName of $scope.charts
        drawChart($scope.charts[chartName])

  displayTooltip = ($placeHolder, $tooltip, points, plot) ->
    $placeHolder.bind "plothover", (event, pos, item) ->
      $tooltip.hide()
      return unless item

      x = parseInt(item.datapoint[0], 10)
      y = parseFloat(item.datapoint[1], 10).toFixed(2)

      found = false
      for point, i in points
        if point[0] == x
          found = true
          break
      return if not found

      date = new Date(x)
      date = date.format()
      radius = 5
      $tooltip.html(y + " at " + date).css({
        top: item.pageY + radius,
        left: item.pageX + radius,
      }).fadeIn(200)


  drawChart = (chart) ->
    $tooltip = $("#tooltip-" + chart.name)
    $placeHolder = $("#chart-" + chart.name)

    $tooltip.css("display", "block")
    $placeHolder.css("display", "block")

    $placeHolder.empty()

    options =
      series:
        curvedLines:
          active: true
        lines:
          show: true
        shadowSize: 0
      grid:
        hoverable: true
        clickable: true
      xaxis:
        axisLabel: "time"
        mode: "time"
      yaxis:
        axisLabel: chart.yAxeLabel

    if ($scope.visibleRange)
      options = $.extend true, {}, options, {
        xaxis: {
          min: $scope.visibleRange["xFrom"],
          max: $scope.visibleRange["xTo"],
        },
      }

    plot = $.plot($placeHolder, chart.line, options)
    displayTooltip($placeHolder, $tooltip, chart.line[0].data, plot)

convert = (src, base)->
  dst = []
  xAvg = yAvg = 0
  modulo = src.length % base
  j = 0;
  for i in [0...src.length]
    j++
    if i == src.length - modulo
      base = modulo
      j = 1
    xAvg += Math.floor(src[i][0] / base)
    yAvg += src[i][1] / base
    if j%base == 0
      dst.push([xAvg, yAvg])
      xAvg = yAvg = 0
  return dst

getXAxeRange = (src)->
  chartLength = src.length
  xFrom = src[0][0]
  xTo = src[chartLength-1][0]
  return [xFrom, xTo]


getVisibleRange = (defaultResolution, range)->
  startPointRange = defaultResolution[1] - range
  if (startPointRange < defaultResolution[0])
    xFrom = defaultResolution[0]
  else xFrom = startPointRange
  return {
    xFrom: xFrom,
    xTo: defaultResolution[1]
  }



getChart = (data, chartInfo, id, resolution, scaleProperties) ->
  lines = []
  for lineName, i in chartInfo.lineNames
    lineData = convert(data[id + "." + lineName], scaleProperties.convertRatio)
    line =
      data: lineData
      color: i+1
      points:
        show: false
      lines:
        show: true
      label: lineName
    lines.push(line)
  return {
      name: chartInfo.name,
      yaxisLabel: chartInfo.yAxeLabel[resolution],
      line: lines,
  }
