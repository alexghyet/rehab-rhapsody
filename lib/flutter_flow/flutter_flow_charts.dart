import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

export 'package:fl_chart/fl_chart.dart'
    show BarAreaData, FlDotData, LineChartBarData, BarChartAlignment;

class FlutterFlowLineChart extends StatelessWidget {
  const FlutterFlowLineChart({
    super.key,
    required this.data,
    required this.chartStylingInfo,
    required this.axisBounds,
    this.xAxisLabelInfo,
    this.yAxisLabelInfo,
  });

  final List<FFLineChartData> data;
  final ChartStylingInfo chartStylingInfo;
  final AxisBounds axisBounds;
  final AxisLabelInfo? xAxisLabelInfo;
  final AxisLabelInfo? yAxisLabelInfo;

  List<LineChartBarData> get dataWithSpots =>
      data.map((d) => d.settings.copyWith(spots: d.data)).toList();

  @override
  Widget build(BuildContext context) => LineChart(
    LineChartData(
      lineTouchData: LineTouchData(
        handleBuiltInTouches: chartStylingInfo.enableTooltip,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (group) =>
              chartStylingInfo.tooltipBackgroundColor ?? Colors.black,
        ),
      ),
      gridData: FlGridData(show: chartStylingInfo.showGrid),
      borderData: FlBorderData(
        border: Border.all(
          color: chartStylingInfo.borderColor,
          width: chartStylingInfo.borderWidth,
        ),
        show: chartStylingInfo.showBorder,
      ),
      titlesData: getTitlesData(xAxisLabelInfo, yAxisLabelInfo),
      lineBarsData: dataWithSpots,
      minX: axisBounds.minX,
      minY: axisBounds.minY,
      maxX: axisBounds.maxX,
      maxY: axisBounds.maxY,
      backgroundColor: chartStylingInfo.backgroundColor,
    ),
  );
}

class FFLineChartData {
  const FFLineChartData({
    required this.xData,
    required this.yData,
    required this.settings,
  });

  final List<dynamic> xData;
  final List<dynamic> yData;
  final LineChartBarData settings;

  List<FlSpot> get data {
    final x = _dataToDouble(xData);
    final y = _dataToDouble(yData);
    assert(x.length == y.length, 'X and Y data must be the same length');
    return Iterable<int>.generate(x.length)
        .where((i) => x[i] != null && y[i] != null)
        .map((i) => FlSpot(x[i]!, y[i]!))
        .toList();
  }
}

class ChartStylingInfo {
  const ChartStylingInfo({
    this.backgroundColor = Colors.white,
    this.showGrid = false,
    this.enableTooltip = false,
    this.tooltipBackgroundColor,
    this.borderColor = Colors.black,
    this.borderWidth = 1.0,
    this.showBorder = true,
  });

  final Color backgroundColor;
  final bool showGrid;
  final bool enableTooltip;
  final Color? tooltipBackgroundColor;
  final Color borderColor;
  final double borderWidth;
  final bool showBorder;
}

class AxisLabelInfo {
  const AxisLabelInfo({
    this.title = '',
    this.titleTextStyle,
    this.showLabels = false,
    this.labelTextStyle,
    this.labelInterval,
    this.labelFormatter,
    this.reservedSize,
  });

  final String title;
  final TextStyle? titleTextStyle;
  final bool showLabels;
  final TextStyle? labelTextStyle;
  final double? labelInterval;
  final String Function(double)? labelFormatter;
  final double? reservedSize;
}

class AxisBounds {
  const AxisBounds({this.minX, this.minY, this.maxX, this.maxY});

  final double? minX;
  final double? minY;
  final double? maxX;
  final double? maxY;
}

FlTitlesData getTitlesData(
  AxisLabelInfo? xAxisLabelInfo,
  AxisLabelInfo? yAxisLabelInfo,
) => FlTitlesData(
  bottomTitles: _axisTitles(xAxisLabelInfo),
  leftTitles: _axisTitles(yAxisLabelInfo),
  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
);

AxisTitles _axisTitles(AxisLabelInfo? info) => AxisTitles(
  axisNameWidget: info == null || info.title.isEmpty
      ? null
      : Text(info.title, style: info.titleTextStyle),
  axisNameSize: info?.titleTextStyle?.fontSize != null
      ? info!.titleTextStyle!.fontSize! + 12
      : 16,
  sideTitles: SideTitles(
    showTitles: info?.showLabels ?? false,
    interval: info?.labelInterval,
    reservedSize: info?.reservedSize ?? 22,
    getTitlesWidget: (value, _) => Padding(
      padding: const EdgeInsets.all(4.0),
      child: Text(
        info?.labelFormatter?.call(value) ?? formatLabel(value),
        style: info?.labelTextStyle,
      ),
    ),
  ),
);

String formatLabel(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

List<double?> _dataToDouble(List<dynamic> data) {
  if (data.isEmpty) {
    return [];
  }
  if (data.first is num) {
    return data.map((d) => (d as num?)?.toDouble()).toList();
  }
  if (data.first is DateTime) {
    return data
        .map((d) => (d as DateTime?)?.millisecondsSinceEpoch.toDouble())
        .toList();
  }
  if (data.first is String) {
    // First try to parse as doubles, falling back to the index.
    final parsed = data.map((d) => double.tryParse(d as String)).toList();
    if (parsed.every((d) => d != null)) {
      return parsed;
    }
    return data.asMap().keys.map((i) => i.toDouble()).toList();
  }
  return data.asMap().keys.map((i) => i.toDouble()).toList();
}
