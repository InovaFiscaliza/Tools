#!/usr/bin/env python
""" Perform tile cleaning operations, including removing null data tiles and merging tiles with the same suffix, as naming convention from degree_tile_split.py.

Parameters:
    TARGET_FOLDER: String containing the path to the folder where the GeoTIFF files are located. 
    TIF_FILES: List of strings containing the paths to the GeoTIFF files to be processed. If None, all files in the TARGET_FOLDER will be used.
    NULL_DATA_TILE_SIZE: Value representing the null data in the geotiff file. Use the script get_null_data_value.py to get the value.
    REMOVE_SOURCE_FILES: Boolean value to indicate if the source files should be removed after merging.
    NO_DATA_VALUE: Integer value representing the NoData value to be used in the merged file.
    
Raises:
    FileNotFoundError: If the specified folder or files are not found.
    Exception: If an error occurs while running the gdalinfo command or saving the metadata to the JSON file.

Returns:
    None:   Merged tiles are saved to the TARGET_FOLDER.
            Log file is saved to clean_tiles.log.
"""

import subprocess
import os
import logging

TARGET_FOLDER = "D:/map/Height_tiles"
NULL_DATA_TILE_SIZE = 1000000
REMOVE_SOURCE_FILES =  True
NO_DATA_VALUE = -32767.0

TIF_FILES = None
"""	
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
# Add a StreamHandler to print logs to the console
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
console_formatter = logging.Formatter('%(asctime)s | %(levelname)s | %(message)s')
console_handler.setFormatter(console_formatter)
logging.getLogger().addHandler(console_handler)

# Add the process id to the log format
log_format = '%(asctime)s | %(levelname)s | %(process)d | %(message)s'
logging.basicConfig(filename='clean_tiles.log',
                    level=logging.INFO,
                    format=log_format)

# Function to run gdalinfo command and parse output
def null_data_tile_removed(file_path: str) -> bool:
    """Get metadata from a GeoTIFF file using the gdalinfo command and check if the file contains only null data. If so, delete the file.

    Args:
        file_path (str): The path to the GeoTIFF file.

    Returns:
        bool: True if the file was deleted or contains valid data, False otherwise.
    """
    
    logging.info(f"Running gdalinfo command on {file_path}")
    
    file_removed = False
    
    # test if the file is smaller than NULL_DATA_TILE_SIZE, which is a common size for null data tiles
    if os.path.getsize(file_path) < NULL_DATA_TILE_SIZE:
        # Run gdalinfo command with -noct -stats and -json options, capture the output and the error to confirm if the file contains only null data
        gdalinfo_output = subprocess.run(['gdalinfo', '-noct', '-stats', '-json', file_path], capture_output=True, text=True)
        
        # test if error include the string "no valid pixels found"
        try:
            if "no valid pixels found" in gdalinfo_output.stderr:
                logging.warning(f"File {file_path} has only null data. Deleting file...")
                os.remove(file_path)
                file_removed = True
        # handle the case where the file can't be removed
        except FileNotFoundError:
            message = f"File {file_path} could not be removed."
            logging.error(message)
            pass
            
        # handle the case where gdalinfo_output.stderr is not defined
        except AttributeError:
            logging.info(f"File {file_path} tested and contains valid data.")
            pass
    
    return file_removed


def tile_merge(file_list: list) -> None:
    """Merge a list of tiles into a single file using the gdal_merge.py command.

    Args:
        file_list (list): A list of file paths to be merged.
    """
    
    logging.info(f"Merging tiles: {file_list}")
    
    # loop through the list of files and extract the prefix from the file names, as defined by the first element separated by the "_" character
    merged_prefix = ""
    for file in file_list:
        filename = os.path.basename(file).split("_",1)
        file_prefix = filename[0]
        merged_prefix = f"{merged_prefix}{file_prefix}-"
    
    # create the merged file name using the prefix and the suffix from the last file in the list
    merged_file_name = f"{merged_prefix[:-1]}_{filename[1]}"
    
    # Get the full root path without the filename from the first file
    path = os.path.dirname(file_list[0])
    
    # Create the output filename using os.path.join
    output_filename = f"{path}/{merged_file_name}"
    
    # Create the command to merge the tiles
    command = [ "python", "C:/Users/lobao/.conda/envs/map/Scripts/gdal_merge.py",
                "-a_nodata", str(NO_DATA_VALUE),
                "-of", "GTiff",
                "-co", "TILED=YES",
                "-co", "COMPRESS=LZW",
                "-co", "PREDICTOR=2",
                "-co", "BIGTIFF=YES",
                "-co", "BLOCKXSIZE=512",
                "-co", "BLOCKYSIZE=512",
                "-o", output_filename] + file_list
    
    # Run the command
    gdal_merge_output = subprocess.run(command)

    if gdal_merge_output.returncode == 0:
        logging.info(f"Files {file_list} merged successfully to {output_filename}")
        # remove the merged files
        for file in file_list:
            if REMOVE_SOURCE_FILES:
                os.remove(file)
            else:
                logging.warning(f"Not removing file {file}")

    else:
        logging.error(f"Error merging files {file_list}")
        

def main():
    logging.info("Starting tile cleaning...")

    # If target folder is not specified, use all TIF_FILES list
    if TARGET_FOLDER is None:
        tif_files = TIF_FILES
    else:
        tif_files = [f"{TARGET_FOLDER}/{file}"   for file in os.listdir(TARGET_FOLDER) if file.endswith(".tif")]

    clean_file_list = tif_files.copy()
    # remove null data tiles
    
    for file_path in tif_files:
        if null_data_tile_removed(file_path):
            clean_file_list.remove(file_path)
    
    # create a dictionary using as key the suffix of the file name after the first "_" character and as value a list of files with that suffix
    tile_dict = {}
    for file in clean_file_list:
        # get the filename without the path using os, avoid erros in case of _ in the path
        filename = os.path.basename(file)
        file_suffix = filename.split("_", 1)[1]
        if file_suffix in tile_dict:
            tile_dict[file_suffix].append(file)
        else:
            tile_dict[file_suffix] = [file]
    
    # merge all files with the same suffix
    for key in tile_dict:
        if len(tile_dict[key]) > 1:
            tile_merge(tile_dict[key])

    logging.info("Tile cleaning finished.")
    
if __name__ == "__main__":
    main()
