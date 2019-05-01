all: final_dat.csv

clean:
	rm temp_*

temp_crime_per_line.txt: homicides.html
	cat homicides.html | egrep 'id="person' | sed 's/<\/div>/&\n/g' | egrep '<div class="person' > $@

temp_ids.txt: temp_crime_per_line.txt
	cat temp_crime_per_line.txt | egrep -o 'person[0-9]+' | sed 's/person//' > $@

temp_addresses.txt: temp_crime_per_line.txt
	cat temp_crime_per_line.txt | egrep -o 'Location of homicide: [^<]*' | sed 's/Location of homicide: //'> $@

temp_dates.txt: temp_crime_per_line.txt
	cat temp_crime_per_line.txt | egrep -o 'Date of homicide: [^<]*' | sed 's/Date of homicide: //' | sed 's/^\([^/]*\)\/\([^/]*\)\/\(.*\)/\3-\1-\2/' | sed 's/-\([0-9]\)-/-0\1-/g'| sed 's/-\([0-9]\)$$/-0\1/' | sed 's/-/\//g' > $@

temp_times.txt: temp_crime_per_line.txt
	cat temp_crime_per_line.txt | egrep -o 'Time of homicide: [^<]*' | sed 's/Time of homicide: //' | while read x; do date -d "$$x" '+%R'; done > $@

temp_time_stamps.csv: temp_times.txt temp_dates.txt
	paste -d ' ' temp_dates.txt temp_times.txt >$@

temp_homicide_final.csv: temp_ids.txt temp_lat_long.csv temp_time_stamps.csv
	paste -d ',' temp_ids.txt temp_time_stamps.csv temp_lat_long.csv | egrep -v '^([0-9]*).*,\1$$' | cut -f 2,3,4 -d "," > $@
	
temp_new_add.csv: temp_ids.txt temp_addresses.txt
	paste -d "," temp_ids.txt temp_addresses.txt | sed 's/.*/&,Chicago,IL,/' > $@

temp_geo_code_results.csv: temp_new_add.csv
	curl --form addressFile=@temp_new_add.csv --form benchmark=9 https://geocoding.geo.census.gov/geocoder/locations/addressbatch --output $@

temp_lat_long.csv: temp_geo_code_results.csv
	cat temp_geo_code_results.csv | cut -d "," -f 1,12,13 | sed 's/"//g' | sort -n | sed 's/[^,]*,//' > $@

final_dat.csv: temp_homicide_final.csv CPDCrimes.csv
	cat CPDCrimes.csv | sed 's/T/ /' | sed 's/-/\//' | sed 's/-/\//' | sed 's/:00\.000//' > $@
	cat temp_homicide_final.csv >> $@

