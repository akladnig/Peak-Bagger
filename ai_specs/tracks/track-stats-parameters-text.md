# Outlier Filter
## Hampel Filter
The Hampel filter is a robust, sliding-window algorithm used to detect and remove outliers in time series data. It calculates the median and Median Absolute Deviation (MAD) within a window, replacing points that deviate significantly (e.g., >3 sigam) from the median, making it less sensitive to outliers than mean-based methods.

### Hampel Window Size
Defines the number of neighbors on each side of the central point. A larger window helps identify outliers in noisier data but may smooth local trends.
- 5-11

### Threshold
Defines the sensitivity for outlier detection. A common default is 3, based on the three-sigma rule. This is fixed in the code: gpx_track_filter.dart.

# Elevation Filter
## Elevation Smoother
- Median

## Savitzky-Golay

The Savitzky-Golay filter is a digital signal processing technique that smooths noisy data or calculates derivatives by performing local least-squares polynomial fitting within a sliding window. It effectively reduces noise while preserving high-frequency signal components (like peak shapes) better than standard moving averages.

### Elevation Window Size
Higher values provide smoother data but may suppress peaks.
- 5-9

### Polynomial Degree
Higher values follow the original signal more closely but may overfit noise.

# Position
## Position Smoother
- Moving Average

### Kalman
A Kalman filter is an optimal estimation algorithm used to predict the internal state of a dynamic system (like position or velocity) by combining noisy measurements with a mathematical model of that system. It is a recursive process, meaning it only needs the previous "best guess" and the latest measurement to calculate a new, more accurate estimate.

### Position Window Size
- 3-5


