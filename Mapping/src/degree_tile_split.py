#!/usr/bin/env python
"""Split a GeoTIFF file into tiles of one degree size based on the metadata information.

Parameters:
    INPUT_FILES: List of strings containing the paths to the input GeoTIFF files.
    METADATA_FILE: METADATA_FILE: String containing the name to the metadata file created by the script check_files.py.
    OUTPUT_FOLDER: String containing the path to the folder where the tiles will be saved.
    BUFFER_PIXEL_SIZE: Integer containing the size of the buffer in pixels to avoid edge artifacts in the merged result.
    NAMING_CONVENTION: String containing the naming convention to be used for the output file name. May be "GEO" or "SRTM".

Raises:
    ValueError: If the naming convention is invalid.

Returns:
    None: The function does not return a value. Tiles are saved to the output folder.
"""

import subprocess
import math
import json

# Define the file paths for the input GeoTIFF files
INPUT_FILES = [ "D:/map/Clutter/AC_Clutter_v3.tif",
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

"""
INPUT_FILES = [ "D:/map/Height/AC_Heights_Vs2.tif",
                "D:/map/Height/AL_Heights_Vs2.tif",
                "D:/map/Height/AM_Heights.tif",
                "D:/map/Height/AP_Heights.tif",
                "D:/map/Height/BA_Heights.tif",
                "D:/map/Height/CE_Heights.tif",
                "D:/map/Height/DF_Heights.tif",
                "D:/map/Height/ES_Heights.tif",
                "D:/map/Height/GO_Heights.tif",
                "D:/map/Height/MA_Heights_v2.tif",
                "D:/map/Height/MG_Heights.tif",
                "D:/map/Height/MS_Heights.tif",
                "D:/map/Height/MT_Heights.tif",
                "D:/map/Height/PA_Heights_v2.tif",
                "D:/map/Height/PB_Heights_VS2.tif",
                "D:/map/Height/PE_Heights_V2.tif",
                "D:/map/Height/PI_Heights_Vs2.tif",
                "D:/map/Height/PR_Heights.tif",
                "D:/map/Height/RJ_Heights.tif",
                "D:/map/Height/RN_Heights.tif",
                "D:/map/Height/RO_Heights.tif",
                "D:/map/Height/RR_Heights.tif",
                "D:/map/Height/RS_Heights.tif",
                "D:/map/Height/SC_Heights.tif",
                "D:/map/Height/SE_Heights_Vs2.tif",
                "D:/map/Height/SP_Heights.tif",
                "D:/map/Height/TO_Heights.tif"]

INPUT_FILES = ["D:/map/Height/AL_Heights_Vs2.tif",
               "D:/map/Height/PE_Heights_V2.tif",
               "D:/map/Height/PB_Heights_VS2.tif"]

INPUT_FILES = ["D:/map/Height/AP_Heights.tif"]
"""

METADATA_FILE = "D:/map/Clutter/metadata.json"

OUTPUT_FOLDER = "D:/map/Clutter_tiles"

BUFFER_PIXEL_SIZE = 2

NAMING_CONVENTION = "GEO"
NAMING_CONVENTION = "SRTM"

def create_tile_name(naming_convention:str,
                     x_ref_coord: int,
                     y_ref_coord: int,
                     prefix: str) -> str:
    """Generate the output file name for the tile based on the reference coordinates.

    Args:
        naming_convention (str): The naming convention to be used for the output file name.
        x_ref_coord (int): The reference x-coordinate for the tile.
        y_ref_coord (int): The reference y-coordinate for the tile.
        prefix (str): The state code extracted from the input file name.

    Returns:
        str: The output file name for the tile.
    """
    global OUTPUT_FOLDER
    
    # Create the tile name based on the naming convention cases
    match naming_convention:
        case "GEO":
    
            if x_ref_coord < 0:
                parallel = "W"
            else:  
                parallel = "E"
            if y_ref_coord < 0:
                meridian = "S"
            else:
                meridian = "N"

            return f"{OUTPUT_FOLDER}/{prefix}_tile_{meridian}{abs(y_ref_coord)}{parallel}{abs(x_ref_coord)}.tif"
        case "SRTM":
            if x_ref_coord < 0:
                raise ValueError("x_ref_coord must be positive for SRTM naming convention")
            if y_ref_coord < 0:
                raise ValueError("y_ref_coord must be positive for SRTM naming convention")
            
            return f"{OUTPUT_FOLDER}/{prefix}_{y_ref_coord}_{x_ref_coord}.tif"
        case _:
            raise ValueError("Invalid naming convention")


def calculate_tile_size(ul_index: int, num_tiles: int, first_tile_size: float, one_degree_size: int, image_size: int) -> int:
    """Calculate the size of a tile in pixels for a given axis.

    Args:
        ul_index (int): The index of the upper left tile in the axis.
        num_tiles (int): The total number of tiles in the axis.
        first_tile_size (float): The size of the first tile in the axis.
        one_degree_size (int): The size of one degree in pixels in the axis.
        image_size (int): The size of the image in the axis.

    Returns:
        int: The size of the tile in pixels.
    """
    last_index = num_tiles - 1
    if ul_index == 0:
        tile_size = int(first_tile_size)
    elif ul_index == last_index:
        tile_size = int(image_size - (ul_index * one_degree_size))
    else:
        tile_size = one_degree_size

    return tile_size
   

# Function to run gdal_translate command
def run_gdal_translate(input_file:str, output_file:str, win_upper_left_x:int, win_upper_left_y:int, window_lower_right_x:int, window_lower_right_y:int) -> None:
    """Run gdal_translate command to create a tile from the input file.

    Args:
        input_file (str): String containing the path to the input file.
        output_file (str): String containing the path to the output file.
        offset_x (int): Pixel offset in the x-direction for the upper left corner of the tile.
        offset_y (int): Pixel offset in the y-direction for the upper left corner of the tile.
        size_x (int): Tile size in pixels in the x-direction.
        size_y (int): Tile size in pixels in the y-direction.
    """
    
    command = [
        "gdal_translate",
        "-of", "GTiff",
        "-co", "TILED=YES",
        "-co", "COMPRESS=LZW",
        "-co", "PREDICTOR=2",
        "-co", "BIGTIFF=YES",
        "-co", "BLOCKXSIZE=512",
        "-co", "BLOCKYSIZE=512",
        "-projwin", str(win_upper_left_x), str(win_upper_left_y), str(window_lower_right_x), str(window_lower_right_y),
        input_file, output_file
    ]
    subprocess.run(command)

def main():
    # load metadata
    with open(METADATA_FILE, "r") as file:
        metadata = json.load(file)
        
    tile_name_offset_x = math.floor(metadata["box"][0])
    tile_name_offset_y = math.ceil(metadata["box"][1])

    # Loop through input files
    for image in INPUT_FILES:
        
        print(f"Processing {image}")
        
        # Get the first two leters of the image name
        state_code = image.split("/")[-1][:2]

        x_buffer = abs(BUFFER_PIXEL_SIZE*metadata[image]["pixelSizeDegrees"][0])
        y_buffer = abs(BUFFER_PIXEL_SIZE*metadata[image]["pixelSizeDegrees"][1])
        
        # Compute the reference coordinates for the first tile as per metadata
        upper_left_image_x_geo_coord = metadata[image]["upperLeftCorner"][0]
        upper_left_image_y_geo_coord = metadata[image]["upperLeftCorner"][1]
        lower_right_image_x_geo_coord = metadata[image]["lowerRightCorner"][0]
        lower_right_image_y_geo_coord = metadata[image]["lowerRightCorner"][1]
        
        upper_left_first_tile_x_geo_coord = math.floor(upper_left_image_x_geo_coord)
        upper_left_first_tile_y_geo_coord = math.ceil(upper_left_image_y_geo_coord)
        lower_right_first_tile_x_geo_coord = upper_left_first_tile_x_geo_coord + 1
        lower_right_first_tile_y_geo_coord = upper_left_first_tile_y_geo_coord - 1
        
        # Calculate number of tiles in each direction
        num_tiles_x = math.ceil(lower_right_image_x_geo_coord) - upper_left_first_tile_x_geo_coord
        num_tiles_y = upper_left_first_tile_y_geo_coord - math.floor(lower_right_image_y_geo_coord)
        
        # Calculate offset and size for each tile
        for ulx in range(num_tiles_x):
            for uly in range(num_tiles_y):
                            
                # Calculate the upper left pixel coordinates for the tile of one degree size
                window_upper_left_x = upper_left_first_tile_x_geo_coord + ulx
                window_upper_left_y = upper_left_first_tile_y_geo_coord - uly
                window_lower_right_x = lower_right_first_tile_x_geo_coord + ulx
                window_lower_right_y = lower_right_first_tile_y_geo_coord - uly
                
                # create tile name
                tile_output_name = create_tile_name(naming_convention=NAMING_CONVENTION,
                                                    x_ref_coord=abs(window_upper_left_x-tile_name_offset_x),
                                                    y_ref_coord=abs(window_upper_left_y-tile_name_offset_y),
                                                    prefix=state_code)
                
                # add buffer to the window to avoid edge artifacts in the merged result
                window_upper_left_x = window_upper_left_x - x_buffer
                window_upper_left_y = window_upper_left_y + y_buffer
                window_lower_right_x = window_lower_right_x + x_buffer
                window_lower_right_y = window_lower_right_y - y_buffer                
                
                if ulx == 0:
                    window_upper_left_x = upper_left_image_x_geo_coord
                elif ulx == num_tiles_x - 1:
                    window_lower_right_x = lower_right_image_x_geo_coord
                    
                if uly == 0:
                    window_upper_left_y = upper_left_image_y_geo_coord
                elif uly == num_tiles_y - 1:
                    window_lower_right_y = lower_right_image_y_geo_coord
                
                print(f"Creating tile {tile_output_name} from ({window_upper_left_x}, {window_upper_left_y}) to ({window_lower_right_x}, {window_lower_right_y}) based on {image}...")

                # Call gdal_translate function
                run_gdal_translate(image, tile_output_name, window_upper_left_x, window_upper_left_y, window_lower_right_x, window_lower_right_y)

if __name__ == "__main__":
    main()