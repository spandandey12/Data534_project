# Mountain Weather Forecasting

This R package provides functions to find nearby mountains summits and to compare weather forecasts of those locations. This would be of interest to mountaineers, to help them decide which mountains to hike near their home or a destination. Weather forecasting is done using the [Open-Meteo API](https://open-meteo.com/). The mountain data is from [Andrew Kirmse](https://www.andrewkirmse.com/prominence-update-2023) in the form of a csv file. Although R wrappers for this API do exist already (such as [ropenmeteo](https://github.com/FLARE-forecast/ropenmeteo) and [openmeteo](https://tpisel.r-universe.dev/openmeteo)), none of these other wrappers have added functionality specific to mountaineering. A vignette is provided to provide an example of how to use the package.

**Dependencies:** `httr2`, `ggplot2`, `readr`, `geosphere`

---

## Functions

### `get_forecast_raw`
A low-level helper function that constructs and sends the API request to Open-Meteo using `httr2`.

* **latitude / longitude**: (Numeric) The coordinates for the forecast.
* **start_date / end_date**: (String) The time window in `YYYY-MM-DD` format.
* **daily_variables**: (Vector) List of daily weather variables to request.
* **hourly_variables**: (Vector) List of hourly weather variables to request.

#### Error Handling:
* Validates **latitude** and **longitude** using **check_lat_lon()** (must be single numeric values and within valid coordinate ranges).
* Validates **start_date** and **end_date** using **check_date_forecast()** (must be valid dates, start_date <= end_date, and end_date must be within 16 days of today due to the Open-Meteo Forecast API limit).
* After the equest is performed, checks **resp_status(response)**. If status is not 200, the function stops with an informative message. If the JSON body contains a **reason** field, it is included in the error message.

#### Unit Testing:
* SOMETHING

### `get_forecast`
Fetches weather data for a specific location and returns a structured dataframe with a formatted time column.

* **latitude / longitude**: (Numeric) Target coordinates.
* **start_date / end_date**: (String) Forecast date range.
* **time_resolution**: (String) Either `"hourly"` or `"daily"`.
* **variables**: (Vector) The weather metrics to retrieve (e.g., temperature, rain, snowfall).

#### Error Handling:
* Ensures **time_resolution** is either **"hourly"** or **"daily"** or else stops with an error
* Ensures **variables** is a non-empty character vertor or else stops with an error.
* Uses get_forecast_raw() to handle coordinate and date validation along with HTTP error checking.

#### Unit Testing:
* SOMETHING

### `get_nearest_mountains`
Finds the closest mountain peaks to a specific coordinate that are above elevation and prominence thresholds.

* **latitude / longitude**: (Numeric) The reference point to measure distance from.
* **num_mountains**: (Integer) Number of results to return (Default: 5).
* **prominence_threshold**: (Numeric) Minimum prominence in meters (Default: 500).
* **elevation_threshold**: (Numeric) Minimum elevation in meters (Default: 0).

#### Error Handling:
* Validates **latitude** and **longitude** using **check_lat_lon()**.
* Validates **num_mountains** is a single numeric value **>1**
* Validates **prominence_threshold** and **elevation_threshold** are single numeric values **>0**.
* If no mountains meet the filtering thresholds, stops with: ** "No mountains match your thresholds. Try lowering prominence_threshold/elevation_threshold."**

#### Unit Testing:
* SOMETHING

### `forecast_mountains`
A wrapper that iterates through a dataframe of mountains to create a comparative weather table.

* **mountains**: (Dataframe) A dataframe containing mountain coordinates (typically the output of `get_nearest_mountains`).
* **start_date / end_date**: (String) Forecast date range.
* **time_resolution**: (String) Either `"hourly"` or `"daily"`.
* **weather_feature**: (String) The specific weather variable to extract into the final table (Default: `"temperature_2m"`).

#### Error Handling:
* Ensures **mountains** is a non-empty dataframe.
* Ensures **mountains** contains **latitude** and **longtitude** columns.
* Ensures **weather_feature** is a single character string.
* If the mountains dataframe has missing/empty rownames, assigns default names (**mountain_1**, **mountain_1**,...) o ensure valid output column names.
* Relies on **get_forecast()**/**get_forecast_raw()** for coordinate/date/API error handling while looping through mountains.

#### Unit Testing:
* SOMETHING
