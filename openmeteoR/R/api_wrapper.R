
# All mountains with over 500 m of prominence
file <- system.file("extdata", "mountains.csv", package = "openmeteoR")

mountains <- read.csv(file, header = TRUE)
# The default weather variables fetched by the API, all are hourly
default_variables <- c(
  "temperature_2m",
  "rain",
  "snowfall",
  "wind_speed_10m",
  "relative_humidity_2m",
  "snow_depth",
  "cloud_cover"
)
# Helpers Validation
check_lat_lon<-function(latitude,longitude) {
  # latitude is a single numeric value  
  if (!is.numeric(latitude) || length(latitude) != 1 || is.na(latitude)) {
    stop("latitude must be a single numeric value (not NA).")
  }
  # longitude is a single numeric value  
  if (!is.numeric(longitude) || length(longitude) != 1 || is.na(longitude)) {
    stop("longitude must be a single numeric value (not NA).")
  }
  # Validate latitude range
  if (latitude < -90 || latitude > 90) {
    stop("latitude must be between -90 and 90.")
  }
  # Validate longtitude range
  if (longitude < -180 || longitude > 180) {
    stop("longitude must be between -180 and 180.")
  }
}
check_date_forecast<-function(start_date,end_date) {
  # Ensure valid dates
  start_date<-as.Date(start_date)
  end_date<-as.Date(end_date)
  if (is.na(start_date) || is.na(end_date)) {
    stop("start_date and end_date must be valid dates like '2026-01-23'.")
  }
  if (start_date > end_date) {
    stop("start_date must be before or equal to end_date.")
  }
  # Open-Meteo Forecast API officially supports forecasts only up to 16 days into the future
  max_end <- Sys.Date() + 16
  if (end_date > max_end) {
    stop(sprintf("end_date is too far in the future. Forecast API supports up to 16 days ahead (max end_date = %s).", max_end))
  }
  list(start_date = start_date, end_date = end_date)
}
# Function to get the raw response from Open-Meteo's API 
get_forecast_raw <- function(latitude,
                             longitude,
                             start_date,
                             end_date,
                             daily_variables = c(),
                             hourly_variables = c()
) {
  
  
  # Error handling. latitude / longitude
  check_lat_lon(latitude,longitude)
  # Error handling. date rules for Forecast API
  dates <- check_date_forecast(start_date, end_date)
  start_date <- format(dates$start_date, "%Y-%m-%d")
  end_date   <- format(dates$end_date, "%Y-%m-%d")
  
  # Calling the Open-Meteo Api
  req <- req_url_query(
    request("https://api.open-meteo.com/v1/forecast"),
    latitude = latitude,
    longitude = longitude,
    start_date = start_date,
    end_date   = end_date,
    daily = paste(daily_variables, collapse = ","),
    hourly = paste(hourly_variables, collapse = ",")
  )
  
  response <- req_perform(req)
  # TODO: Error handling. For resp_status(resp) != 200, print cause of error
  if(resp_status(response)!=200){
    err_json<- tryCatch(resp_body_json(response), error = function(e) NULL)
    if (!is.null(err_json) && !is.null(err_json$reason)){
      stop(sprintf("Open-Meteo API request failed (HTTP %s): %s", resp_status(response), err_json$reason))
    }else{
      stop(sprintf("Open-Meteo API request failed (HTTP %s).", resp_status(response)))
    }
  }
  response
}

# Function to get the forecast over a date range as a dataframe
get_forecast <- function(latitude,
                         longitude,
                         start_date,
                         end_date,
                         time_resolution = "hourly",
                         variables = default_variables
){
  
  # Error handling: making sure time_resolution is "hourly" or "daily"
  if(!time_resolution %in% c("hourly", "daily")){
    stop('time_resolution must be "hourly" or "daily".')
  }
  # Error Handling: Variables
  if(!is.character(variables) || length(variables) < 1){
    stop("variables must be a non-empty character vector.")
  }
  if (time_resolution == "hourly") {	
    response <- get_forecast_raw(
      latitude = latitude,
      longitude = longitude,
      start_date = start_date,
      end_date = end_date,
      hourly_variables = variables
    )
  } else {
    response <- get_forecast_raw(
      latitude = latitude,
      longitude = longitude,
      start_date = start_date,
      end_date = end_date,
      daily_variables = variables
    )
  }
  
  data_json <- resp_body_json(response)
  
  if (time_resolution == "hourly") {	
    weather_data <- as.data.frame(lapply(data_json$hourly, function(x) unlist(x))) # Making each variable a column in the dataframe
    weather_data$time <- as.POSIXct(weather_data$time, format = "%Y-%m-%dT%H:%M") # Making time a datetime column in the dataframe
  } else {
    weather_data <- as.data.frame(lapply(data_json$daily, function(x) unlist(x))) # Making each variable a column in the dataframe
    weather_data$time <- as.Date(weather_data$time, format = "%Y-%m-%d") # Making time a date column in the dataframe
  }
  
  weather_data
}

# Function to get the nearest mountains to an input point as a dataframe with distance in km
get_nearest_mountains <- function(latitude,
                                  longitude, 
                                  num_mountains = 5, 
                                  prominence_threshold = 500, 
                                  elevation_threshold = 0
) {
  
  # Error handling: latitude/longitude
  check_lat_lon(latitude,longitude)
  # Error handling: num_mountains is 1 or more
  if(!is.numeric(num_mountains)||length(num_mountains)!=1||is.na(num_mountains)||num_mountains<1){
    stop("num_mountains must be a single number >= 1.")
  }
  num_mountains <- as.integer(num_mountains)
  # Error handling: prominence_threshold is 0 or more
  if(!is.numeric(prominence_threshold)||length(prominence_threshold)!=1||is.na(prominence_threshold)||prominence_threshold<0){
    stop("prominence_threshold must be a single number >= 0.")
  }
  # Error handling: elevation_threshold is 0 or more
  if (!is.numeric(elevation_threshold) || length(elevation_threshold) != 1 || is.na(elevation_threshold) || elevation_threshold < 0) {
    stop("elevation_threshold must be a single number >= 0.")
  }
  
  mountains_temp <- mountains[mountains$prominence >= prominence_threshold & mountains$elevation >= elevation_threshold, ]
  
  input_coord <- c(longitude, latitude)
  mountain_coords <- mountains_temp[, c("longitude", "latitude")]
  # if mountain_coords is zero
  if (nrow(mountains_temp) == 0) {stop("No mountains match your thresholds. Try lowering prominence_threshold/elevation_threshold.")}
  distances <- round(distHaversine(mountain_coords, input_coord) / 1000, 1) # Converting m to km for distance
  mountains_temp$distance_km <- distances
  
  mountains_sorted <- mountains_temp[order(mountains_temp$distance_km), ]
  
  head(mountains_sorted, num_mountains)
}

# Function to get the forecast over a date range for mountains in the form of a dataframe
forecast_mountains <- function(mountains, 
                               start_date, 
                               end_date, 
                               time_resolution = "hourly",
                               weather_feature = "temperature_2m"
) {
  
  # Error handling: mountains is a non-empty dataframe
  if (!is.data.frame(mountains) || nrow(mountains)==0) {
    stop("mountains must be a non-empty dataframe.")
  }
  # Error handling: mountains has latitude and longitude columns
  if (!all(c("latitude", "longitude") %in% names(mountains))) {
    stop("mountains must contain columns: latitude and longitude.")
  }
  # Error handling: weather_feature must be a single string
  if(!is.character(weather_feature) || length(weather_feature) != 1){
    stop("weather_feature must be a single character string, e.g. 'temperature_2m'.")
  }
  # Error handling: If no rowname
  if(is.null(rownames(mountains)) || any(rownames(mountains) == "")) {
    rownames(mountains) <- sprintf("mountain_%d", seq_len(nrow(mountains)))
  }
  mountain_weather <- data.frame()
  
  for (i in 1:nrow(mountains)) {
    mountain <- mountains[i, ]
    
    forecast <- get_forecast(mountain$latitude, 
                             mountain$longitude, 
                             start_date, 
                             end_date, 
                             time_resolution,
                             weather_feature)
    
    if (!"time" %in% colnames(mountain_weather)) {
      mountain_weather <- data.frame(matrix(nrow = nrow(forecast), ncol = 0))
      mountain_weather$time <- forecast$time
    }
    
    mountain_column_name <- rownames(mountain)
    mountain_weather[mountain_column_name] <- forecast[[weather_feature]]
  }
  
  mountain_weather
}

