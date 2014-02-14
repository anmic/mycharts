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
  $scope.resolution = "day"

  $scope.$watch "resolution", ->
    chartsData.getData($scope.resolution, $scope.id).then (data) ->
      $scope.charts = {}
      for chartInfo in chartsInfo
        $scope.charts[chartInfo.name] = getChart(data, chartInfo, $scope.id, $scope.resolution)

      points =  $scope.charts[chartInfo.name].line[0].data
      $scope.defaultResolution = getXAxeRange(points)
      $scope.visibleRange = $scope.defaultResolution
    , (errorMessage) ->
      $scope.error = errorMessage

  $scope.$watch("visibleRange", ->
    return unless $scope.visibleRange
    for chartName of $scope.charts
      drawChart($scope.charts[chartName])
  , true)  

  $scope.zoomOut = -> 
    $scope.visibleRange = $scope.defaultResolution

  $scope.drawYearChart = ->
    $scope.visibleRange = $scope.defaultResolution
    $scope.resolution = "year"

  $scope.drawHourChart = ->
    $scope.visibleRange = $scope.defaultResolution
    $scope.resolution = "day"

  selectRange = (placeHolder)->
    placeHolder.bind "plotselected", (event, ranges) ->
      $scope.$apply ->
        $scope.visibleRange = {
          xFrom: ranges.xaxis.from,
          xTo: ranges.xaxis.to
        }

  displayTooltip = ($placeHolder, $tooltip, points) ->
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
      selection:
        mode: "x"
      xaxis:
        axisLabel: "time"
        mode: "time"
      yaxis:
        axisLabel: chart.yAxeLabel

    if ($scope.visibleRange)
      options = $.extend(true, {}, options, {
        xaxis: {
          min: $scope.visibleRange["xFrom"],
          max: $scope.visibleRange["xTo"],
        },
      })

    $.plot($placeHolder, chart.line, options)

    selectRange($placeHolder);
    displayTooltip($placeHolder, $tooltip, chart.line[0].data)

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


getChart = (data, chartInfo, id, resolution) ->
  lines = []
  for lineName, i in chartInfo.lineNames
    lineData = convert(data[id + "." + lineName], 3)
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
