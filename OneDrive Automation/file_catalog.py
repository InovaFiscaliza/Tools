#!/usr/bin/python
""" Check files in a folder and update a catalog file with new data.
    Move files from post folder to get folder

Args (stdin): ctrl+c will soft stop the process similar to kill command or systemd stop <service>. kill -9 will hard stop.

Returns (stdout): As log messages, if target_screen in log is set to True.

Raises:
    Exception: If any error occurs, the exception is raised with a message describing the error.
"""

import json

import logging
import coloredlogs

import signal
import inspect

import os
import shutil
import glob
import pandas as pd
import time

# Global Constants
CONFIG_FILE = "D:/Documents/Anatel/Aplicativos/GitHub/Tools/OneDrive Automation/config.json"

# Global variables
config = None
keep_watching = True
log = None

# define a class that initializes loading the config file and set methods to get the values
class Config:
    """Class to load and store the configuration values from a JSON file."""

    def __init__(self):
        """Load the configuration values from a JSON file. in format:
            {
                "check period in seconds":5,
                "clean period in hours":24,
                "last clean":"2021-09-30 15:00:00",
                "folders":{
                    "root":"D:/OneDrive",
                    "post":"/post/Regulatron",
                    "temp":"/temp/Regulatron",
                    "trash":"/trash/Regulatron",
                    "screeshots":"/get/Regulatron/Screeshots"},
                "catalog":"/get/Regulatron/Anuncios.xlsx",
                "log":{
                    "level":"INFO",
                    "screen output":true,
                    "file output":true,
                    "file path":"/get/Regulatron/log.xlsx"},
                    "columns":{
                        "in":["nome", "preço", "avaliações", "nota", "imagem", "url", "data", "palavra_busca", "página_de_busca", "certificado", "características", "descrição", "ean_gtin", "estado", "estoque", "imagens", "fabricante", "modelo", "product_id", "vendas", "vendedor", "screenshot", "indice", "subcategoria", "nome_sch", "fabricante_sch", "modelo_sch", "tipo_sch", "nome_score", "modelo_score", "passível?", "probabilidade", "marketplace"],
                        "out":["nome", "preço", "avaliações", "nota", "imagem", "url", "data", "palavra_busca", "página_de_busca", "certificado", "características", "descrição", "ean_gtin", "estado", "estoque", "imagens", "fabricante", "modelo", "product_id", "vendas", "vendedor", "screenshot", "indice", "subcategoria", "nome_sch", "fabricante_sch", "modelo_sch", "tipo_sch", "nome_score", "modelo_score", "passível?", "probabilidade", "marketplace", "status_screenshot"]}
            }
        """
        global CONFIG_FILE
        
        raw = None
        
        try:
            with open(CONFIG_FILE) as f:
                self.raw = json.load(f)
        except FileNotFoundError:
            print(f"Config file not found in path: {CONFIG_FILE}")
            exit(1)
            
        self.post = os.path.join(raw["folders"]["root"], raw["folders"]["post"])
        self.temp = os.path.join(raw["folders"]["root"], raw["folders"]["temp"])
        self.trash = os.path.join(raw["folders"]["root"], raw["folders"]["trash"])
        self.screenshots = os.path.join(raw["folders"]["root"], raw["folders"]["screenshots"])
        self.catalog = os.path.join(raw["folders"]["root"], raw["catalog"])
        self.log_level = raw["log"]["level"]
        self.log_screen = raw["log"]["screen output"]
        self.log_file = raw["log"]["file output"]
        self.log_filename = os.path.join(raw["folders"]["root"], raw["log"]["file path"])
        self.columns_in = raw["columns"]["in"]
        self.columns_out = raw["columns"]["out"]
        self.check_period = raw["check period in seconds"]
        self.clean_period = raw["clean period in hours"]
        # convert last clean to datetime
        self.last_clean = pd.to_datetime(raw["last clean"], format="%Y-%m-%d %H:%M:%S")
    
    def reload(self):
        """Reload the configuration values from the JSON file."""
        self.__init__()
        
    def set_last_clean(self):
        """Write current datetime to JSON file."""
        
        self.raw["last clean"] = pd.to_datetime("now").strftime("%Y-%m-%d %H:%M:%S")
        
        try:
            with open(CONFIG_FILE, 'w') as f:
                json.dump(self.raw, f)
        except Exception as e:
            print(f"Error writing to config file: {e}")
    
# Define a signal handler for SIGTERM (kill command )
def sigterm_handler(signal=None, frame=None) -> None:
    """Signal handler for SIGTERM (Kill) to stop the process."""

    global keep_watching
    global log

    current_function = inspect.currentframe().f_back.f_code.co_name
    log.critical(f"Kill signal received at: {current_function}()")
    keep_watching = False


# Define a signal handler for SIGINT (Ctrl+C)
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

def start_logging():
    """Start the logging system with the configuration values from the config file and updating global variables.

    Returns:
        bool: True if the logging system was started successfully.
    """
    global log
    global config
    
    coloredlogs.install()

    log = logging.getLogger('Regulatron Catalog')
    
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
        ch = logging.StreamHandler()
        ch.setFormatter(logging.Formatter("%(asctime)s | %(name)s | %(levelname)s | %(message)s (%(filename)s:%(lineno)d)"))
        log.addHandler(ch)
    
    if config.log_file:
        fh = logging.FileHandler(config.log_filename)
        fh.setFormatter(logging.Formatter("%(asctime)s | %(name)s | %(levelname)s | %(message)s (%(filename)s:%(lineno)d)"))
        log.addHandler(fh)    
    
    log.info("Starting file catalog script...")

    return True

def clean_post_folder():
    """Move new files from the post folder to the temp folder and return the list of files to process.

    Returns:
        list[str]: List of files to process in the temp folder.
    """
    
    global log
    global config

    # Get content from folder
    folder_content = glob.glob(config.post, recursive=True)
    
    if not folder_content:
        log.info("Nothing new in the post folder.")
        return []
    
    # loop through the items in the post folder
    xlsx_to_process = []
    pdf_to_process = []
    subfolders = []
    for item in folder_content:
        
        # Check if the item is a file
        if os.path.isfile(os.path.join(config.post, item)):
            
            # Check if the file is a new .xlsx file
            if item.endswith('.xlsx'):
                # Move new files to the temp folder
                shutil.move(os.path.join(config.post, item), config.temp)
                xlsx_to_process.append(item)
                log.info(f"Moved to {config.temp} the file {item}")
            # else if file is pdf
            elif item.endswith('.pdf'):
                shutil.move(os.path.join(config.post, item), config.temp)
                pdf_to_process.append(item)
                log.info(f"Moved to {config.temp} the file {item}")
            else:
                shutil.move(os.path.join(config.post, item), config.trash)
                log.info(f"Moved to {config.trash} the file {item}")
        else:
            subfolders.append(item)
    
    # Remove empty subfolders after moving files. New files that may have appered in the subfolders will be processed in the next run
    if subfolders:
        for folder in subfolders:
            if not os.listdir(os.path.join(config.post, folder)):
                os.rmdir(os.path.join(config.post, folder))
                log.info(f"Removed folder {folder}")
            
    return xlsx_to_process, pdf_to_process

def deep_clean_post():
    """Move all files older than the clean period in hours from the post folder to the trash folder."""
    
    global log
    global config

    # Get content from folder
    folder_content = glob.glob(config.post, recursive=True)
    
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

# create logger
def main():
    """Main function"""
    
    config = Config()
    
    start_logging()
    
    while keep_watching:
        
        xlsx_to_process, pdf_to_process = clean_post_folder()
        
        if xlsx_to_process:

            reference_df = pd.read_excel(config.catalog)
            reference_df.set_index("screenshot", inplace=True)            
            
            for file in xlsx_to_process:
                new_data_df = pd.read_excel(os.path.join(config.temp, file))
                
                # test if new_data_df has the columns as defined in the config file
                if new_data_df.columns.tolist() != config.columns_in:
                    log.error(f"Columns in {file} do not match the expected columns.")
                    shutil.move(os.path.join(config.temp, file), config.trash)
                    continue
                
                new_data_df.set_index("screenshot", inplace=True)
                
                reference_df = reference_df.combine_first(new_data_df)
                
        if pdf_to_process:
                
            for file in pdf_to_process:                
                
                if file in reference_df.index:
                    reference_df.at[file, "status_screenshot"] = 1
                else:
                    # if file is not present in the reference_df, just do nothing and wait for it to appear later.
                    log.info(f"{file} not found in the reference data.")

        try:
            reference_df.to_excel(config.catalog, index=False)
            log.info(f"Reference data file updated: {config.catalog}")
        except Exception as e:
            log.error(f"Error saving reference data: {e}")
            continue
        
        # sleep for the check period
        time.sleep(config.check_period)
        
        if pd.to_datetime("now") - config.last_clean > pd.Timedelta(hours=config.clean_period):
            deep_clean_post()
            config.set_last_clean()

if __name__ == "__main__":
    main()
