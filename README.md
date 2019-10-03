# Geocodes to NUTS region: a quick way to transform longitude-latitudes to NUTS3 regions

When working with European regional datasets, scholars often use the NUTS classification provided by Eurostat from the European Commission. The classification provides researchers with the ability to match datasets from different sources. However, not all regional datasets come with NUTS identifiers, but they provide geocodes (lon-lat codes) instead. Thus, one might want to match geocoded datasets with the NUTS classification and then merge based on NUTS1/2/3. The script simplifies the matching process. 

	source('src/geo2nuts.R')
	data("world.cities")
    df <- world.cities %>%
        rename(lon = long, lat = lat) %>%
        mutate(iso3 = countrycode(country.etc, 'country.name', 'iso3c')) %>%
        subset(., !is.na(iso3))
    df_nuts <- geo2nuts(df = df, year = 2016, distance = T)

The original dataset has to include two variables: lon and lat. If distance matching is set to TRUE (default: FALSE), then a iso3 variable also has to be included.