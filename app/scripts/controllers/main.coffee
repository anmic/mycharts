mod = angular.module("myApp", ["ngRoute", "chieffancypants.loadingBar"])


mod.config ($routeProvider)->
  $routeProvider
    .when "/",
      templateUrl: "views/main.html",
      controller: "mainCtrl"
    .when "/charts/:id",
      templateUrl: "views/charts.html",
      reloadOnSearch: false,
      controller: "chartCtrl"

mod.controller "mainCtrl", ($scope) ->
  $scope.chartsList = {
    firstchart: "t.http.POST-notifier_api-v1-notices",
    secondChart: "t.http.POST-notifier_api-v2-notices",
    thirdChart: "t.http.POST-notifier_api-v3-notices"
  }

mod.config (cfpLoadingBarProvider) ->
  cfpLoadingBarProvider.includeBar = true
  cfpLoadingBarProvider.includeSpinner = false

updateTimer = null

mod.controller "chartCtrl", ($scope, $location, $timeout, chartsData, 
    $routeParams, $rootScope
) ->

  console.log "controller start"

  $scope.periods = [
    {
      name: "year",
      label: "Year",
      convertRatio: 3,
      resolution: "year", 
      duration: 31536000000,
      updateInterval: 86400000,
      isSelected: false
    },
    {
      name: "quarter",
      label: "Quarter",
      convertRatio: 2,
      resolution: "year", 
      duration: 7776000000,
      updateInterval: 86400000,
      isSelected: false
    },
    {
      name: "month",
      label: "Month",
      convertRatio: 2,
      resolution: "year", 
      duration: 2592000000,
      updateInterval: 86400000,
      isSelected: false
    },
    {
      name: "week",
      label: "Week",
      convertRatio: 1,
      resolution: "year", 
      duration: 604800000,
      updateInterval: 3600000,
      isSelected: false
    },
    {
      name: "day",
      label: "Day",
      convertRatio: 3,
      resolution: "day", 
      duration: 86400000,
      updateInterval: 6000,
      isSelected: false
    },
    {
      name: "hour",
      label: "Hour",
      convertRatio: 1,
      resolution: "day", 
      duration: 3600000,
      updateInterval: 1000,
      isSelected: false
    }
  ]

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
      },
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

  $scope.chartId = $routeParams.id
  $scope.isRefreshing = true 

  $scope.$watch "period", () ->
    updateChart()
  , true


  $scope.$on('$routeUpdate', ->
    if $scope.period.name != $routeParams.trackingInterval
      $scope.chooseInterval($routeParams.trackingInterval)
  )

  $scope.$watch "isRefreshing", ->
    updateChart()


  $scope.chooseInterval = (name) ->
    for period in $scope.periods
      period.isSelected = false
      if period.name == name
        $scope.period = period
        period.isSelected = true

    $location.search(trackingInterval: name)

  $scope.chooseInterval("day");

  updateChart = () ->
    chartsData.getData($scope.period.resolution, $scope.chartId).then (data) ->
      $scope.charts = {}
      for chartInfo in chartsInfo
        $scope.charts[chartInfo.name] = getChart(
          data,
          chartInfo,
          $scope.chartId,
          $scope.period
        )

      redrawCharts()

      if updateTimer != null
        $timeout.cancel(updateTimer)

      if $scope.isRefreshing        
        updateInterval = $scope.period.updateInterval
        updateTimer = $timeout(->
          updateChart()
        , updateInterval)

    , (errorMessage) ->
      $scope.error = errorMessage


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

getVisibleLineSegment = (src, duration) ->
  dst = []
  xTo = src[src.length-1][0]
  xFrom = xTo - duration
  for i in [0...src.length]
    if src[i][0] >= xFrom
      dst.push(src[i])
  return dst
  
getChart = (data, chartInfo, id, scaleProperties) ->
  lines = []
  for lineName, i in chartInfo.lineNames
    lineData = convert(data[id + "." + lineName], scaleProperties.convertRatio)
    
    visibleLineSegment = getVisibleLineSegment(lineData, scaleProperties.duration)

    line =
      data: visibleLineSegment
      color: i+1
      points:
        show: false
      lines:
        show: true
      label: lineName
    lines.push(line)
  return {
      name: chartInfo.name,
      yaxisLabel: chartInfo.yAxeLabel[scaleProperties.resolution],
      line: lines,
  }
