mod = angular.module("myApp", ["ngRoute"])

mod.config ($routeProvider)->
  $routeProvider
    .when "/",
      templateUrl: "views/main.html",
      controller: "mainCtrl"
    .when "/charts/:id",
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

  $scope.id = $routeParams.id
  $scope.resolution = "day"

  $scope.$watch "resolution", ->
    chartsData.getData($scope.resolution, $scope.id).then (data) ->
      $scope.data = data
      redrawCharts()
    , (errorMessage) ->
      $scope.error = errorMessage

  $scope.$watch("zoom", ((newVal, oldVal) ->
    if $scope.zoom
      updateChart()
  ), true)  


  
  $scope.zoomOut = -> 
    $scope.zoom = $scope.initResolution

  $scope.drawYearChart = ->
    $scope.zoom = $scope.initResolution
    $scope.resolution = "year"

  $scope.drawHourChart = ->
    $scope.zoom = $scope.initResolution
    $scope.resolution = "day"

  getYaxesLabel = (resolution, chartName) ->
    yaxisLabel = {
      "year" : {
        N: "RPH",
        MeanStddev : "ms",
        Max : "ms",
        Min: "ms",
      }
      "day" : {
        N: "RPM",
        MeanStddev: "ms",
        Max: "ms",
        Min: "ms",
      }
    }
    return yaxisLabel[resolution][chartName]

  getLines = ->
    lines = {}
    options = []
    points = []
    for lineName, i in $scope.lineNames
      convertedData = convert($scope.data[$scope.id + "." + lineName], 3)

      line =
        data: convertedData
        color: i+1
        points:
          show: false
        lines:
          show: true
        label: lineName

      options.push(line)
      lines.options = options
      lines.points = convertedData
    return lines

  redrawCharts = () ->
    lineNamesInCharts = [
      ["n"],
      ["mean", "stddev"] ,
      ["max"],
      ["min"]
    ]
    $scope.chartNames = []
    $scope.charts = {}

    for lineNames in lineNamesInCharts
      $scope.lineNames = lineNames
      chartName = ""

      for lineName, i in lineNames
        chartName = chartName + lineName.substr(0, 1).toUpperCase() + lineName.substr(1)
      $scope.chartNames.push(chartName)

      yaxisLabel = getYaxesLabel($scope.resolution, chartName)
      lines = getLines()

      $scope.charts[chartName] = {
        name: chartName,
        points : lines.points,
        line: lines.options,
        chartLabel: chartName,
        yaxisLabel: yaxisLabel
      }

    $scope.initResolution = getInitResolution(lines.points)
    $scope.zoom = $scope.initResolution

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
      $scope.$apply ->
        $scope.zoom = {
          xFrom: ranges.xaxis.from,
          xTo: ranges.xaxis.to
        }

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

getInitResolution = (src)->
  chartLength = src.length
  xFrom = src[0][0]
  xTo = src[chartLength-1][0]
  initResolution = {
    xFrom: xFrom,
    xTo: xTo
  }
  return initResolution