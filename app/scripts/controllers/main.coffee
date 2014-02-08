mod = angular.module("myApp", ["ngRoute"])

mod.config ($routeProvider)->
  $routeProvider
    .when "/",
      templateUrl: "views/main.html",
      controller: "mainCtrl"
    .when "/charts/:address",
      templateUrl: "views/charts.html",
      controller: "chartCtrl"


mod.directive "ngRightClick", ($parse) ->
  return (scope, element, attrs) -> 
    fn = $parse(attrs.ngRightClick)
    element.bind "contextmenu", (event) -> 
      scope.$apply ->
        event.preventDefault()
        fn(scope, {$event:event})


mod.controller "mainCtrl", ($scope) ->
  $scope.chartsList = {
    firstchart: "t.http.POST-notifier_api-v1-notices",
    secondChart: "t.http.POST-notifier_api-v2-notices",
    thirdChart: "t.http.POST-notifier_api-v3-notices"
  }


mod.controller "chartCtrl", ($scope, chartsData, $routeParams) ->
  # init new parameter
  $scope.id = $routeParams.address
  $scope.resolution = "day"

  # watch for zoon &resolution

  $scope.$watch "resolution", ->
    chartsData.getData($scope.resolution, $scope.id).then (data) -> 
      redrawCharts(data)
    , (errorMessage) ->
      $scope.error = errorMessage

  $scope.$watch("zoom", ((newVal, oldVal) ->
    if $scope.zoom
      updateChart()
  ), true)  


  # convert points in average points
  convert = (src, base)->
    dst = []
    dstLen = Math.floor(src.lemngth / base)
    i = 0
    xSum = ySum = 0
    for point in src
      i++
      xSum += point[0]
      ySum += point[1]
      if i%base == 0
        xAvg = xSum / base
        yAvg = ySum / base
        dst.push([xAvg,yAvg])
        xSum = ySum = 0
    modulo = src.length % base 
    if modulo
      xSum = ySum = 0
      for i in [1..modulo]
        xSum += src[src.length - i][0]
        ySum += src[src.length - i][1]
      xAv = xSum / modulo
      yAv = ySum / modulo
      dst.push([xAv,yAv])
    return dst

  $scope.zoomOut = -> 
    $scope.zoom = $scope.initResolution

  $scope.drawYearChart = ->
    $scope.zoom = $scope.initResolution
    $scope.resolution = "year"

  $scope.drawHourChart = ->
    $scope.zoom = $scope.initResolution
    $scope.resolution = "day"

  redrawCharts = (data) ->

    lineNamesInCharts = [
      ["n"],
      ["mean", "stddev"] ,
      ["max"],
      ["min"]
    ]

    $scope.chartNames = []

    lines = []

    fullName = $scope.id + "." + lineNamesInCharts[0][0]
    chartLength = data[fullName].length
    xFrom = data[fullName][0][0]
    xTo = data[fullName][chartLength-1][0]
    $scope.initResolution = {
      xFrom: xFrom,
      xTo: xTo
    }
    $scope.charts = {}
    i=1;
    for lineNames in lineNamesInCharts
      $scope.zoom = $scope.initResolution
      $scope.data = data

      yaxisLabel = "ms"
      if lineNames[0] == "n"
        if $scope.resolution == "year"
          yaxisLabel = "RPH"
        if $scope.resolution == "day"
          yaxisLabel = "RPM"
  
      chartName = ""

      chartColors = i
      i++
      lines = []
      chartPoints = []
      for lineName in lineNames

        chartName = chartName + lineName.substr(0, 1).toUpperCase() + lineName.substr(1)
        convertedLine = convert(data[$scope.id + "." + lineName], 3)
        chartPoints = convertedLine
        line =
          data: convertedLine
          color: chartColors
          points:
            show: false
          lines:
            show: true
          label: lineName

        lines.push(line)

      $scope.chartNames.push(chartName)

      $scope.charts[chartName] = {
        name: chartName,
        points : chartPoints
        line: lines,
        chartLabel: chartName,
        yaxisLabel: yaxisLabel
      }
    # updateChart()


  updateChart = ->
    for chartName in $scope.chartNames
      drawChart $scope.charts[chartName]

  drawChart = (chart) ->

    $tooltip = $("#tooltip" + chart.name)
    $placeHolder = $("#chart" + chart.name)

    $tooltip.css("display", "block")
    $placeHolder.css "display", "block"

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
      selection:
        mode: "x"
      xaxis:
        axisLabel: "time"
        mode: "time"
      yaxis:
        axisLabel: chart.yaxisLabel

    if ($scope.zoom)
      options = $.extend(true, {}, options, {
        xaxis: {
          min: $scope.zoom["xFrom"],
          max: $scope.zoom["xTo"],
        },
      })


    $.plot($placeHolder, chart.line, options)

    $placeHolder.bind "plotselected", (event, ranges) ->
      $scope.zoom = {
        xFrom: ranges.xaxis.from,
        xTo: ranges.xaxis.to
      }
      $scope.$apply()

    $placeHolder.bind "plothover", (event, pos, item) ->
      $tooltip.hide()
      return unless item

      needed = parseInt(item.datapoint[0], 10)
      res = $.grep chart.points, (v, _) ->
        return v[0] == needed
      return if res.length is 0

      x = parseInt(item.datapoint[0], 10)
      y = parseFloat(item.datapoint[1], 10).toFixed(2)

      date = new Date(x)
      date = date.format()
      radius = 5
      $tooltip.html(y + " at " + date).css({
        top: item.pageY + radius,
        left: item.pageX + radius,
      }).fadeIn 200