#!/usr/bin/env python
""" Extract metadata from a list of GeoTIFF files and save it to a JSON file.

Parameters:
    TARGET_FOLDER: String containing the path to the folder where the GeoTIFF files are located. If None, all files in the TIF_FILES list will be used.
    TIF_FILES: List of strings containing the paths to the GeoTIFF files to be processed.
    METADATA_FILE: String containing the name to the metadata file to be saved in the same folder as the GeoTIFF files.
    
Raises:
    FileNotFoundError: If the specified folder or files are not found.
    Exception: If an error occurs while running the gdalinfo command or saving the metadata to the JSON file.

Returns:
    None: The metadata is saved to a JSON file.
"""

import subprocess
import json
import os

METADATA_FILE = "metadata.json"
# TARGET_FOLDER = "D:/srtm"
# TARGET_FOLDER = "D:/map/Height"
TARGET_FOLDER = "D:/map/Clutter"
# TARGET_FOLDER = none

# List of GeoTIFF files
TIF_FILES = None
"""
tif_files =["D:/map/Clutter/AC_Clutter_v3.tif",
            "D:/map/Clutter/AL_Clutter_v5.tif",
            "D:/map/Clutter/AM_Clutter.tif",
            "D:/map/Clutter/AP_Clutter.tif",
            "D:/map/Clutter/BA_Clutter_v2.tif",
            "D:/map/Clutter/CE_Clutter_v2.tif",
            "D:/map/Clutter/DF_Clutter_v3.tif",
            "D:/map/Clutter/ES_Clutter_v3.tif",
            "D:/map/Clutter/GO_Clutter_2.tif",
            "D:/map/Clutter/MA_Clutter_v3.tif",
            "D:/map/Clutter/MG_Clutter_v2.tif",
            "D:/map/Clutter/MS_Clutter_v5.tif",
            "D:/map/Clutter/MT_Clutter_V3.tif",
            "D:/map/Clutter/PA_Clutter_v2.tif",
            "D:/map/Clutter/PB_Clutter_v2.tif",
            "D:/map/Clutter/PE_Clutter_v2.tif",
            "D:/map/Clutter/PI_Clutter_v3.tif",
            "D:/map/Clutter/PR_Clutter_v3.tif",
            "D:/map/Clutter/RJ_Clutter_v5.tif",
            "D:/map/Clutter/RN_Clutter_v2.tif",
            "D:/map/Clutter/RO_Clutter.tif",
            "D:/map/Clutter/RR_Clutter.tif",
            "D:/map/Clutter/RS_Clutter_v5.tif",
            "D:/map/Clutter/SC_Clutter_v5.tif",
            "D:/map/Clutter/SE_Clutter_v3.tif",
            "D:/map/Clutter/SP_Clutter_v2.tif",
            "D:/map/Clutter/TO_Clutter_v3.tif"]

TIF_FILES =["D:/map/Clutter/tiles/AL_tile_S7W36.tif",
            "D:/map/Clutter/tiles/AL_tile_S7W37.tif",
            "D:/map/Clutter/tiles/AL_tile_S7W38.tif",
            "D:/map/Clutter/tiles/AL_tile_S7W39.tif",
            "D:/map/Clutter/tiles/AL_tile_S8W36.tif",
            "D:/map/Clutter/tiles/AL_tile_S8W37.tif",
            "D:/map/Clutter/tiles/AL_tile_S8W38.tif",
            "D:/map/Clutter/tiles/AL_tile_S8W39.tif",
            "D:/map/Clutter/tiles/SE_tile_S7W37.tif",
            "D:/map/Clutter/tiles/SE_tile_S7W38.tif",
            "D:/map/Clutter/tiles/SE_tile_S7W39.tif",
            "D:/map/Clutter/tiles/SE_tile_S8W37.tif",
            "D:/map/Clutter/tiles/SE_tile_S8W38.tif",
            "D:/map/Clutter/tiles/SE_tile_S8W39.tif",
            "D:/map/Clutter/tiles/SE_tile_S9W37.tif",
            "D:/map/Clutter/tiles/SE_tile_S9W38.tif",
            "D:/map/Clutter/tiles/SE_tile_S9W39.tif"]
"""

# Command to merge tiles using gdal_merge.py
# gdal_merge -o merged.tif D:\map\Clutter\tiles\AL_tile_S7W36.tif D:\map\Clutter\tiles\AL_tile_S7W37.tif D:\map\Clutter\tiles\AL_tile_S7W38.tif D:\map\Clutter\tiles\AL_tile_S7W39.tif D:\map\Clutter\tiles\AL_tile_S8W36.tif D:\map\Clutter\tiles\AL_tile_S8W37.tif D:\map\Clutter\tiles\AL_tile_S8W38.tif D:\map\Clutter\tiles\AL_tile_S8W39.tif D:\map\Clutter\tiles\SE_tile_S7W37.tif D:\map\Clutter\tiles\SE_tile_S7W38.tif D:\map\Clutter\tiles\SE_tile_S7W39.tif D:\map\Clutter\tiles\SE_tile_S8W37.tif D:\map\Clutter\tiles\SE_tile_S8W38.tif D:\map\Clutter\tiles\SE_tile_S8W39.tif D:\map\Clutter\tiles\SE_tile_S9W37.tif D:\map\Clutter\tiles\SE_tile_S9W38.tif D:\map\Clutter\tiles\SE_tile_S9W39.tif

# gdaldem hillshade -of PNG merged.tif merged_hillshade.png


# Function to run gdalinfo command and parse output
def get_gdalinfo(file_path):
    # Run gdalinfo command
    gdalinfo_output = subprocess.run(['gdalinfo', '-noct', '-json', file_path], capture_output=True, text=True)

    # Parse gdalinfo output
    gdalinfo_dict = json.loads(gdalinfo_output.stdout)
    
    # Extract required metadata
    try:
        upper_left_corner = gdalinfo_dict["cornerCoordinates"]["upperLeft"]
    except KeyError:
        upper_left_corner = [None, None]
        
    try:
        lower_right_corner = gdalinfo_dict["cornerCoordinates"]["lowerRight"]
    except KeyError:
        lower_right_corner = [None, None]
        
    try:
        image_size = gdalinfo_dict["size"]
    except KeyError:
        image_size = [None, None]
        
    try:
        pixel_size_x = gdalinfo_dict["geoTransform"][1]
    except KeyError:
        pixel_size_x = None
        
    try:
        pixel_size_y = gdalinfo_dict["geoTransform"][5]
    except KeyError:
        pixel_size_y = None
    
    try:
        projection = gdalinfo_dict["coordinateSystem"]["wkt"]
    except KeyError:
        projection = None

    return {
        "upperLeftCorner": upper_left_corner,
        "lowerRightCorner": lower_right_corner,
        "imageSize": image_size,
        "pixelSizeDegrees": [pixel_size_x, pixel_size_y],
        "projection": projection
    }

# Function to check if all files have the same pixel size and projection
def check_consistency(tif_files:(list), metadata:(dict)) -> dict:
    
    # Check if all files have the same pixel size and projection
    for file_path in tif_files:
        
        # test if metadata[file_path]["pixelSizeDegrees"][0] is a key in the dictionary metadata["used_x_pixel_size"]
        if metadata[file_path]["pixelSizeDegrees"][0] in metadata["used_x_pixel_size"]:
            metadata["used_x_pixel_size"][metadata[file_path]["pixelSizeDegrees"][0]] += 1
        else:
            metadata["used_x_pixel_size"][metadata[file_path]["pixelSizeDegrees"][0]] = 1
            
        # test if metadata[file_path]["pixelSizeDegrees"][1] is a key in the dictionary metadata["used_y_pixel_size"]
        if metadata[file_path]["pixelSizeDegrees"][1] in metadata["used_y_pixel_size"]:
            metadata["used_y_pixel_size"][metadata[file_path]["pixelSizeDegrees"][1]] += 1
        else:
            metadata["used_y_pixel_size"][metadata[file_path]["pixelSizeDegrees"][1]] = 1
            
        # test if metadata[file_path]["projection"] is a key in the dictionary metadata["used_projections"]
        if metadata[file_path]["projection"] in metadata["used_projections"]:
            metadata["used_projections"][metadata[file_path]["projection"]] += 1
        else:
            metadata["used_projections"][metadata[file_path]["projection"]] = 1
            
    return metadata

def main():

    print("Starting metadata extraction...")

    # If target folder is not specified, use all TIF_FILES list
    if TARGET_FOLDER is None:
        tif_files = TIF_FILES
    else:
        tif_files = [f"{TARGET_FOLDER}/{file}" for file in os.listdir(TARGET_FOLDER) if file.endswith(".tif")]

    # Dictionary to store metadata for each file
    metadata = {"box":[1000.0, -1000.0, -1000.0, 1000.0],
                "used_x_pixel_size": {},
                "used_y_pixel_size": {},
                "used_projections": {}}

    # Get metadata for each file
    for file_path in tif_files:
        metadata[file_path] = get_gdalinfo(file_path)

        # Get the reference coordinates for the upper left corner of the image
        metadata["box"][0] = min(metadata["box"][0], metadata[file_path]["upperLeftCorner"][0])
        metadata["box"][1] = max(metadata["box"][1],metadata[file_path]["upperLeftCorner"][1])
        metadata["box"][2] = max(metadata["box"][2], metadata[file_path]["lowerRightCorner"][0])
        metadata["box"][3] = min(metadata["box"][3], metadata[file_path]["lowerRightCorner"][1])

        print(f"Metadata extracted for {file_path}")

    # Check consistency of pixel size and projection
    metadata = check_consistency(tif_files=tif_files, metadata=metadata)

    #get the full root path without te filename from the first file
    path = os.path.dirname(tif_files[0])

    output_filename = f"{path}\{METADATA_FILE}"

    # Save metadata to JSON file
    with open(output_filename, 'w') as json_file:
        json.dump(metadata, json_file, indent=4)

    print(f"Metadata saved to {output_filename}")

if __name__ == "__main__":
    main()