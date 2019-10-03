# load packages
pacman::p_load(plyr, dplyr, eurostat, readxl, tidyr, countrycode, sp, rgdal, stringr, geosphere, ggmap, rgeos, maps)

# determine the NUTS region of the geocodes
geo2nuts <- function(df, year = 2016, distance = F){

  # error messages
  if(!(('lon' %in% colnames(df)) & ('lat' %in% colnames(df)))){
      stop('lon or lat variable not available')
  }
  if(distance == T & !('iso3' %in% colnames(df))){
      stop('distance matching allowed, but not iso3 variable provided')
  }

  # define objects and parameters
  geo_df <- df %>% mutate(rowID = str_pad(1:nrow(.), nchar(nrow(df))+1, pad = "0"))
  crs <- CRS(sprintf("+proj=utm +zone=%d +datum=NAD83 +units=m +no_defs +ellps=GRS80 +towgs84=0,0,0", 32))

  # load shapefile
  shape_object <- get_eurostat_geospatial(output_class = "spdf", resolution = "10", nuts_level = 3, year = year)
  shape_object@data <- shape_object@data %>% mutate(iso3 = countrycode(CNTR_CODE, 'eurostat', 'iso3c'))
  nuts_countries <- unique(shape_object@data$iso3)

  # match based on over
  temp <- geo_df %>%
      subset(., !is.na(lon) & !is.na(lat)) %>%
      SpatialPointsDataFrame(.[,c('lon', 'lat')], ., proj4string = CRS(shape_object@proj4string@projargs)) %>%
      over(., shape_object) %>% select(NUTS_ID) %>% merge(geo_df, . , by = 'row.names', all.x = T) %>% select(-'Row.names')
  temp_distance <- temp %>% subset(., is.na(NUTS_ID)) %>% select(colnames(geo_df))
  temp_over <- temp %>% subset(., !rowID %in% temp_distance$rowID) %>% mutate(matching_type = 'over')
  temp_missing <- geo_df %>% subset(., is.na(lon) | is.na(lat)) %>% mutate(NUTS_ID = 'no geocodes', matching_type = 'no geocodes')

  # match based on lowest distance
  if(distance == TRUE & nrow(temp_distance)>0){
      pUTM <- spTransform(shape_object, crs)
      ptsUTM <- temp_distance %>% SpatialPointsDataFrame(.[,c('lon', 'lat')], ., proj4string = crs)
      nearest_nuts <- data.frame(stringsAsFactors = F)
      for (i in 1:length(ptsUTM)) {
          pUTM_temp <- pUTM %>% subset(., iso3 == ptsUTM[i,]$iso3)
          if(length(pUTM_temp@data$NUTS_ID)==0){
              nearest_nuts <- 'outside'
          } else{
              nearest_nuts <- pUTM_temp@data[which.min(gDistance(ptsUTM[i,], pUTM_temp, byid=TRUE)),] %>% pull(NUTS_ID)
          }
          temp_distance$NUTS_ID[i] <- nearest_nuts
      }
      temp_distance <- temp_distance %>%
          mutate(matching_type = 'distance') %>%
          mutate(matching_type = replace(matching_type, NUTS_ID == 'outside', 'outside'))
  } else{
      temp_distance <- temp_distance %>% mutate(NUTS_ID = 'no distance matching', matching_type = 'no distance matching')
  }

  # return results
  res <- temp_over %>% rbind.fill(., temp_distance) %>% rbind.fill(., temp_missing)
  return(res)
}
