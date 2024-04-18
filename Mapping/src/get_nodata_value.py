#!/usr/bin/env python
""" Get the nodata value from a GeoTIFF file.

Parameters:
    
Raises:

Returns:
"""

from osgeo import gdal

FILE_PATH = "D:/map/Height/AL_Heights_Vs2.tif"

def get_nodata_value(file_path: str) -> int:
    """Get the nodata value from a GeoTIFF file.

    Args:
        file_path (str): The path to the GeoTIFF file.

    Returns:
        int: The nodata value.
    """
    # Open the GeoTIFF file
    dataset = gdal.Open(file_path)
    if dataset is None:
        raise FileNotFoundError(f"Could not open file: {file_path}")

    # Get the nodata value from the metadata
    nodata_value = dataset.GetRasterBand(1).GetNoDataValue()

    # Close the dataset
    dataset = None

    return nodata_value

def main():
    global FILE_PATH

    nodata_value = get_nodata_value(FILE_PATH)
    print(f"Nodata value from {FILE_PATH}: {nodata_value}")
    
if __name__ == "__main__":
    main()