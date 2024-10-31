#!/usr/bin/python
"""
Check files in a folder and update a catalog file with new data.
Keep folders clean by moving old files to a trash folder.
Move files from post folder to get folder
This module will not stop execution on file errors, except on startup. It will log the error and continue.

Args (stdin): ctrl+c will soft stop the process similar to kill command or systemd stop <service>. kill -9 will hard stop.

Returns (stdout): As log messages, if target_screen in log is set to True.

Raises:
    Exception: If any error occurs, the exception is raised with a message describing the error.
"""

import logging
import sys
import coloredlogs

import signal
import inspect

import os
import shutil
import glob

import json
import pandas as pd
import time

# Global Constants
CONFIG_FILE = "D:/Documents/Anatel/Aplicativos/GitHub/Tools/OneDrive Automation/src/config.json"

# Global variables
config = None
keep_watching = True
log = None

# --------------------------------------------------------------
class Config:
    """Class to load and store the configuration values from a JSON file."""

    def __init__(self) -> None:
        """Load the configuration values from a JSON file encoded with UTF-8 and with the following tags:
            {
                "check period in seconds":5,
                "clean period in hours":24,
                "last clean":"2021-09-30 15:00:00",
                "folders":{
                    "root":"D:/OneDrive",
                    "post":"post/Regulatron",
                    "temp":"temp/Regulatron",
                    "trash":"trash/Regulatron",
                    "screenshots":"get/Regulatron/Screenshots"},
                "catalog":"get/Regulatron/Anuncios.xlsx",
                "log":{
                    "level":"INFO",
                    "screen output":true,
                    "file output":true,
                    "file path":"get/Regulatron/log.txt"},
                    "columns":{
                        "in":["nome", "preço", "avaliações", "nota", "imagem", "url", "data", "palavra_busca", "página_de_busca", "certificado", "características", "descrição", "ean_gtin", "estado", "estoque", "imagens", "fabricante", "modelo", "product_id", "vendas", "vendedor", "screenshot", "indice", "subcategoria", "nome_sch", "fabricante_sch", "modelo_sch", "tipo_sch", "nome_score", "modelo_score", "passível?", "probabilidade", "marketplace"],
                        "out":["nome", "preço", "avaliações", "nota", "imagem", "url", "data", "palavra_busca", "página_de_busca", "certificado", "características", "descrição", "ean_gtin", "estado", "estoque", "imagens", "fabricante", "modelo", "product_id", "vendas", "vendedor", "screenshot", "indice", "subcategoria", "nome_sch", "fabricante_sch", "modelo_sch", "tipo_sch", "nome_score", "modelo_score", "passível?", "probabilidade", "marketplace", "status_screenshot"]}
            }
        """
        self.load_config()
        
        self.post = os.path.join(self.raw["folders"]["root"], self.raw["folders"]["post"])
        self.temp = os.path.join(self.raw["folders"]["root"], self.raw["folders"]["temp"])
        self.trash = os.path.join(self.raw["folders"]["root"], self.raw["folders"]["trash"])
        self.screenshots = os.path.join(self.raw["folders"]["root"], self.raw["folders"]["screenshots"])
        self.catalog = os.path.join(self.raw["folders"]["root"], self.raw["catalog"])
        self.log_level = self.raw["log"]["level"]
        self.log_screen = self.raw["log"]["screen output"]
        self.log_file = self.raw["log"]["file output"]
        self.log_filename = os.path.join(self.raw["folders"]["root"], self.raw["log"]["file path"])
        self.columns_in = sorted(self.raw["columns"]["in"])
        self.columns_out = self.raw["columns"]["out"]
        self.columns_key = self.raw["columns"]["key"]
        self.check_period = self.raw["check period in seconds"]
        self.clean_period = self.raw["clean period in hours"]
        self.last_clean = pd.to_datetime(self.raw["last clean"], format="%Y-%m-%d %H:%M:%S")
        
        if not self.is_config_ok():
            exit(1)
    
    # --------------------------------------------------------------
    def load_config(self) -> None:
        """Load the configuration values from a JSON file encoded with UTF-8.
        """
        
        global CONFIG_FILE
        
        try:
            with open(CONFIG_FILE, 'r', encoding='utf-8') as json_file:
                self.raw = json.load(json_file)
        except FileNotFoundError:
            print(f"Config file not found in path: {CONFIG_FILE}")
            exit(1)
    
    # --------------------------------------------------------------
    def reload(self) -> None:
        """Reload the configuration values from the JSON file."""
        self.__init__()

    # --------------------------------------------------------------
    def set_last_clean(self) -> None:
        """Write current datetime to JSON file."""
        
        self.raw["last clean"] = pd.to_datetime("now").strftime("%Y-%m-%d %H:%M:%S")
        
        try:
            with open(CONFIG_FILE, 'w', encoding='utf-8') as json_file:
                json.dump(self.raw, json_file, indent=4)
        except Exception as e:
            print(f"Error writing to config file: {e}")
    
    # --------------------------------------------------------------
    def is_config_ok(self) -> bool:
        """Test if the configuration folders and files exist. Test if log folder is writable. Test if config file is writable.

        Returns:
            bool: True if all folders and files exist and are writable.
        """
        
        if not os.path.exists(self.post):
            print(f"Post folder not found: {self.post}")
            return False
        
        if not os.path.exists(self.temp):
            print(f"Temp folder not found: {self.temp}")
            return False
        
        if not os.path.exists(self.trash):
            print(f"Trash folder not found: {self.trash}")
            return False
        
        if not os.path.exists(self.screenshots):
            print(f"Screenshots folder not found: {self.screenshots}")
            return False
        
        if not os.path.exists(self.catalog):
            print(f"Catalog file not found: {self.catalog}")
            return False
        
        if self.log_file:
            if not os.path.exists(os.path.dirname(self.log_filename)):
                print(f"Log folder not found: {os.path.dirname(self.log_filename)}")
                return False
            try:
                with open(self.log_filename, 'a') as log_file:
                    pass
            except Exception as e:
                print(f"Error writing to log file: {e}")
                return False
        
        try:
            with open(CONFIG_FILE, 'a') as json_file:  
                pass
        except Exception as e:
            print(f"Error writing to config file: {e}")
            return False
        
        return True

# --------------------------------------------------------------
def sigterm_handler(signal=None, frame=None) -> None:
    """Signal handler for SIGTERM (Kill) to stop the process."""

    global keep_watching
    global log

    current_function = inspect.currentframe().f_back.f_code.co_name
    log.critical(f"Kill signal received at: {current_function}()")
    keep_watching = False

# --------------------------------------------------------------
def sigint_handler(signal=None, frame=None) -> None:
    """Signal handler for SIGINT (Ctrl+C) to stop the process."""

    global process_status
    global log

    current_function = inspect.currentframe().f_back.f_code.co_name
    log.critical(f"Ctrl+C received at: {current_function}()")
    process_status["running"] = False

# Register the signal handler function, to handle system kill commands
signal.signal(signal.SIGTERM, sigterm_handler)
signal.signal(signal.SIGINT, sigint_handler)

# --------------------------------------------------------------
def start_logging() -> bool:
    """Start the logging system with the configuration values from the config file and updating global variables.

    Returns:
        bool: True if the logging system started successfully.
    """
    global log
    global config
    
    log = logging.getLogger('Regulatron Catalog')
    
    # Drop all existing handlers
    if log.hasHandlers():
        log.handlers.clear()
        
    coloredlogs.install()
    coloredlogs.ColoredFormatter(fmt='\x1b[32m%(asctime)s\x1b[0m | \x1b[35m%(hostname)s\x1b[0m | \x1b[34m%(name)s[%(process)d]\x1b[0m | \x1b[1;30m%(levelname)s | \x1b[0m %(message)s')
    
    match config.log_level:
        case 'DEBUG':
            log.setLevel(logging.DEBUG)
        case 'INFO':
            log.setLevel(logging.INFO)
        case 'WARNING':
            log.setLevel(logging.WARNING)
        case 'ERROR':
            log.setLevel(logging.ERROR)
        case 'CRITICAL':
            log.setLevel(logging.CRITICAL)
        case _:
            log.setLevel(logging.INFO)            

    if config.log_screen:
        ch = logging.StreamHandler(stream=sys.stdout)
        log.addHandler(ch)
    
    if config.log_file:
        fh = logging.FileHandler(config.log_filename)
        # set the logging format with same fields as the coloredlogs
        formatter = logging.Formatter("%(asctime)s | %(module)s: %(funcName)s:%(lineno)d | %(name)s[%(process)d] | %(levelname)s | %(message)s")
        fh.setFormatter(formatter)
        log.addHandler(fh)
    
    log.info("Starting file catalog script...")

    return True

# --------------------------------------------------------------
def move_to_temp(file: str) -> str:
    """Move a file to the temp folder and return the new path.

    Args:
        file (str): File to move.

    Returns:
        str: New path of the file in the temp folder.
    """
    
    global log
    global config
    
    filename = os.path.basename(file)
    try:
        shutil.move(file, config.temp)
        log.info(f"Moved to {config.temp} the file {filename}")
        return os.path.join(config.temp, filename)
    except Exception as e:
        log.error(f"Error moving {file} to temp folder: {e}")
        return file

# --------------------------------------------------------------
def sort_files_into_lists(  folder_content: list[str],
                            move: bool = True,
                            xlsx_to_process: list[str] = None,
                            pdf_to_process: list[str] = None,
                            subfolders: list[str] = None) -> tuple[list[str], list[str], list[str]]:
    """Sort files in the provided listo into list of xlsx and pdf files to process and subfolders to remove.

    Args:
        files (list[str]): List of files to sort.
        move (bool): True if required to move files to the temp folder.
        xlsx_to_process (list[str]): Existing list of xlsx files to process.
        pdf_to_process (list[str]): Existing list of pdf files to process.
        subfolders (list[str]): Existing list of subfolders to remove.

    Returns:
        tuple[list[str], list[str], list[str]]: List of xlsx files to process, list of pdf files to process, list of subfolders to remove.
    """
    
    global log
    global config

    # Initialize lists if they are None
    if xlsx_to_process is None:
        xlsx_to_process = []
    if pdf_to_process is None:
        pdf_to_process = []
    if subfolders is None:
        subfolders = []
        
    for item in folder_content:
        
        # Check if the item is a file
        if os.path.isfile(item):
            
            # Classify the file by extension
            _, ext = os.path.splitext(item)
            match ext:
                
                case '.xlsx':
                    if move:                        
                        item = move_to_temp(item)

                    xlsx_to_process.append(item)
                    
                case '.pdf':
                    if move:
                        item = move_to_temp(item)
                    
                    pdf_to_process.append(item)
                
                case _:
                    shutil.move(item, config.trash)
                    log.warning(f"Moved to {config.trash} the file {item}")
        else:
            subfolders.append(item)
            
    return xlsx_to_process, pdf_to_process, subfolders

# --------------------------------------------------------------
def remove_unused_subfolders(subfolders: list[str]) -> None:
    """Remove empty subfolders from the post folder.

    Args:
        subfolders (list[str]): List of subfolders to remove.
    """
    
    global log
    global config
    
    if subfolders:
        for folder in subfolders:
            if not os.listdir(os.path.join(config.post, folder)):
                try:
                    os.rmdir(os.path.join(config.post, folder))
                    log.info(f"Removed folder {folder}")
                except Exception as e:
                    log.warning(f"Error removing folder {folder}: {e}")

# --------------------------------------------------------------
def get_files_to_process() -> tuple[list[str], list[str]]:
    """Move new files from the post folder to the temp folder and return the list of files to process.

    Returns:
        list[str]: List of xlsx files to process.
        list[str]: List of pdf files to process.
    """
    
    global log
    global config

    # Get files from temp folder
    folder_content = glob.glob("**", root_dir=config.temp, recursive=True)
    
    if not folder_content:
        log.info("Nothing forgotten in the temp folder.")
    else:
        # add path to filenames
        folder_content = list(map(lambda x: os.path.join(config.temp, x), folder_content))

    xlsx_to_process, pdf_to_process, subfolders = sort_files_into_lists(folder_content, move=False)
    
    # Get files from post folder
    folder_content = glob.glob("**", root_dir=config.post, recursive=True)
    
    if not folder_content:
        log.info("Nothing new in the post folder.")
    else:
        # add path to filenames
        folder_content = list(map(lambda x: os.path.join(config.post, x), folder_content))
        
    xlsx_to_process, pdf_to_process, subfolders = sort_files_into_lists(folder_content, xlsx_to_process=xlsx_to_process, pdf_to_process=pdf_to_process, subfolders=subfolders)
            
    # Remove empty subfolders after moving files. New files that may have appeared in the subfolders will be processed in the next run
    remove_unused_subfolders(subfolders)
    
    return xlsx_to_process, pdf_to_process

# --------------------------------------------------------------
def clean_post_folder() -> None:
    """Move all files older than the clean period in hours from the post folder to the trash folder."""
    
    global log
    global config

    # Get content from folder
    folder_content = glob.glob("**", root_dir=config.post, recursive=True)
    
    if not folder_content:
        log.info("Nothing to clean in the post folder.")
        return
    
    folder_to_remove = []
    
    for item in folder_content:
            
            # Check if the item is a file
            if os.path.isfile(os.path.join(config.post, item)):
                
                # Check if the file is older than the clean period
                if pd.to_datetime(os.path.getctime(os.path.join(config.post, item)), unit='s') < pd.to_datetime("now") - pd.Timedelta(hours=config.clean_period):
                    # Move old files to the trash folder
                    shutil.move(os.path.join(config.post, item), config.trash)
                    log.info(f"Moved to {config.trash} the file {item}")
            else:
                # Check if the folder is empty
                if not os.listdir(os.path.join(config.post, item)):
                    folder_to_remove.append(item)

    # Remove empty subfolders after moving files. New files that may have appered in the subfolders will be processed in the next run
    if folder_to_remove:
        for folder in folder_to_remove:
            os.rmdir(os.path.join(config.post, folder))
            log.info(f"Removed folder {folder}")

# --------------------------------------------------------------
def read_excel(file: str) -> pd.DataFrame:
    """Read an Excel file and return a DataFrame.

    Args:
        file (str): Excel file to read.

    Returns:
        pd.DataFrame: DataFrame with the Excel data.
    """
    global log
    global config
    
    try:
        df_from_file = pd.read_excel(file)
    except Exception as e:
        log.error(f"Error reading Excel file {file}: {e}")
        return pd.DataFrame()
    
    try:
        df_from_file.set_index(config.columns_key, inplace=True)
    except Exception as e:
        log.error(f"Error setting index in reference data: {e}")

    return df_from_file

# --------------------------------------------------------------
def valid_data(df: pd.DataFrame) -> bool:
    """Validate the data in the DataFrame.

    Args:
        df (pd.DataFrame): DataFrame to validate.

    Returns:
        bool: True if the data is valid.
    """
    global log
    global config
    
    if sorted(df.columns) != config.columns_in:
        return False
    
    return True

# --------------------------------------------------------------
def process_xlsx_files(xlsx_to_process: list[str]) -> pd.DataFrame:
    """Process the list of xlsx files and update the reference data file.

    Args:
        xlsx_to_process (list[str]): List of xlsx files to process.
        config (Config): Configuration object.
        log (logging.Logger): Logger object.
    """
    
    global log
    global config
    
    reference_df = read_excel(config.catalog)
    reference_changed = False
    

    for file in xlsx_to_process:
        new_data_df = read_excel(file)

        if not valid_data(new_data_df):
            log.error(f"Invalid data in {file}.")
                    # test if new_data_df has the columns as defined in the config file
            try:
                shutil.move(file, config.trash)
                log.warning(f"Moved to {config.trash} the file {file}")
            except Exception as e:
                log.error(f"Error moving {file} to trash folder: {e}")
                
            continue
        
        # update the reference data with the new data where index matches
        reference_df.update(new_data_df)
        
        # add new_data_df rows where index does not match
        reference_df = reference_df.combine_first(new_data_df)
        
        reference_changed = True

    if reference_changed:
        persist_reference(reference_df)

# --------------------------------------------------------------
def process_pdf_files(pdf_to_process: list[str]) -> None:
    """Process the list of pdf files and update the reference data file.

    Args:
        pdf_to_process (list[str]): List of pdf files to process.
        reference_df (pd.DataFrame): Reference data DataFrame.
        log (logging.Logger): Logger object.
    """
    global log
    global config
        
    reference_df = read_excel(config.catalog)
    reference_changed = False
    
    for item in pdf_to_process:
        filename = os.path.basename(item)
        if filename in reference_df.index:
            reference_df.at[filename, "status_screenshot"] = 1
            reference_changed = True
            
        else:
            # if file is not present in the reference_df, just do nothing and wait for it to appear later.
            log.info(f"{filename} not found in the reference data.")

    if reference_changed:
        persist_reference(reference_df)
    
# --------------------------------------------------------------
def persist_reference(reference_df: pd.DataFrame) -> None:
    """Persist the reference DataFrame to the catalog file.

    Args:
        reference_df (pd.DataFrame): The reference DataFrame to be saved.
    """
    global log
    global config

    # reorder columns to match the config file
    reference_df = reference_df[config.columns_out]
    
    try:
        reference_df.to_excel(config.catalog, index=False)
        log.info(f"Reference data file updated: {config.catalog}")
    except Exception as e:
        log.error(f"Error saving reference data: {e}")

# --------------------------------------------------------------
def clean_old_files() -> None:
    """Check if it's time to clean the post folder and update the last clean time in the config file."""
    global config

    if pd.to_datetime("now") - config.last_clean > pd.Timedelta(hours=config.clean_period):
        clean_post_folder()
        config.set_last_clean()

# --------------------------------------------------------------
# Main function
# --------------------------------------------------------------
def main():
    """Main function"""
    
    global config
    global keep_watching
    
    config = Config()
    
    start_logging()
    
    # keep thread running until a crtl+C or kill command is received, even if an error occurs
    while keep_watching:
        
        try:
            xlsx_to_process, pdf_to_process = get_files_to_process()
            
            if xlsx_to_process:
                process_xlsx_files(xlsx_to_process)
                    
            if pdf_to_process:
                process_pdf_files(pdf_to_process)
            
            clean_old_files()
            
            time.sleep(config.check_period)
        
        except Exception as e:
            log.error(f"Error in main loop: {e}")
            continue

if __name__ == "__main__":
    main()
