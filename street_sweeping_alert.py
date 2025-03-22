import geopandas as gpd
import pandas as pd
from shapely import wkt
from simplepush import send
import requests
from datetime import datetime, timedelta, timezone
from shapely.geometry import Point, LineString
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

# Access the variables
API_key = os.getenv("API_KEY")
device_id = os.getenv("DEVICE_ID")
database_url = os.getenv("DATABASE_URL")

# load street sweeping schedule
df = pd.read_csv("SSS.csv")

df = df[df['Line'].notnull()]  
df['Line'] = df['Line'].astype(str)
df['geometry'] = df['Line'].apply(wkt.loads)
gdf = gpd.GeoDataFrame(df, geometry='geometry')

# get the gps coordinates from today

now = datetime.now(timezone.utc)
last24 = now - timedelta(days=2)

last_24_iso = last24.strftime("%Y-%m-%dT%H:%M:%SZ")

url = database_url
payload = {
    "APIKey": API_key,
    "DeviceID": device_id,
    "DateTime_Start": last_24_iso,
}

response = requests.post(url, json=payload)

if response.status_code == 200:
    print("Success - got gps data!")
    #get the latest lat and lon from the gps reports
    gpsreports = response.json()['GPSReports']
    if len(gpsreports) > 1:
        lat, lon = gpsreports[0]['Latitude'], gpsreports[0]['Longitude']
        point = Point(lon, lat)
        gdf['distance'] = gdf['geometry'].distance(point)
        # Now we need to choose which side of the road we're on
        decide_between = gdf.sort_values(by='distance')[:2]

        # lets try to figure out what side of the street we're parked on

        line = decide_between['geometry'].iloc[0]

        # Find the closest point on the line to the test point
        closest_point = line.interpolate(line.project(point))

        blockside= ''

        if point.y > closest_point.y:  # North or South
            if point.x > closest_point.x:
                blockside = 'NorthEast'
            elif point.x < closest_point.x:
                blockside = 'NorthWest'
            else:
                blockside = 'North'
        elif point.y < closest_point.y:
            if point.x > closest_point.x:
                blockside = 'SouthEast'
            elif point.x < closest_point.x:
                blockside = 'SouthWest'
            else:
                blockside = 'South'
        else:  # Same latitude
            if point.x > closest_point.x:
                blockside = 'East'
            elif point.x < closest_point.x:
                blockside = 'West'
            else:
                blockside = 'On the Line'

        parking_loc_sss = decide_between[decide_between.BlockSide == blockside]
        main_street = parking_loc_sss['Corridor'].iloc[0]
        limits = parking_loc_sss['Limits'].iloc[0].split('-')
        # Need to add some error handling here - what if these calculations
        # dont result in the blocksides that are available?

        # Check when street sweeping happens based on where you're parked
        weekday = now.weekday()
        day_of_month = now.day

        occurrence = (day_of_month - 1) // 7 + 1

        weekdays = ['Mon', 'Tues', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

        # Print the result
        print('It is currently', weekdays[weekday],occurrence)

        for i in range(9):
            day_to_check = now + timedelta(days=i)
            weekday = weekdays[day_to_check.weekday()]
            day_of_month = day_to_check.day
            occurrence = (day_of_month - 1) // 7 + 1
            if (parking_loc_sss['WeekDay'].iloc[0] == weekday) and (parking_loc_sss[f'Week{occurrence}'].iloc[0] == 1):
                if i == 1:
                    title = 'Street Sweeping Tomorrow!'
                else:
                    title = f'Street sweeping in {i} days.'
                message = f'You are parked on the {blockside} side of {main_street} between {limits[0].strip()} and {limits[1].strip()}.'
                send("adamgent", message, title=title, event="sweeperbeeper")
    else:
        print('beep boop not failing')

else:
    print(f"Error {response.status_code}: {response.text}")

