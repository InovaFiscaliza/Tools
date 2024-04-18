<details>
    <summary>Table of Contents</summary>
    <ol>
        <li><a href="#about-Mapping">About Mapping</a></li>
        <li><a href="#Scripts_and_Files">Algorithm Overview</a></li>
        <li><a href="#setup">Setup</a></li>
        <li><a href="#roadmap">Roadmap</a></li>
        <li><a href="#contributing">Contributing</a></li>
        <li><a href="#license">License</a></li>
    </ol>
</details>

# About Mapping

This is a set of scripts that perform file p

## Scripts and Files

| Script module | Description |
| --- | --- |
| [name_paths.ps1](./src/name_path.ps1) | Change file names to include prefix according to folder structure. Used tho harmonize names with the ones used for tiling. e.g. file .\map\df\map.tif becomes .\map\df\df_map.tif |
| [sort_files.ps1](./src/sort_files.ps1) | Organize files into foldes according to naming templates |
| [remove_empty_folders.ps1](./src/remove_empty_folders.ps1) | Remove empty folders from file three |
| [check_files.py](./src/check_files.py) | Check if all files are present in the folder structure. Used to check if all files are present before tiling |
| [degree_tile_split.py](./src/degree_tile_split.py) | Split a set of source geotiff files containing regions of no data values, e.g. valid data only within a state political boundry, into a set of regular tiles spawning the complete dataset, e.g convert multiple state maps into a national map tile grid  |
| [get_nodata_value.py](./src/get_nodata_value.py) | get the value used to represent no data in a geotiff |
| [clean_tiles.py](./src/clean_tiles.py) | merge overlapping tiles and delete empty tiles from a list of geotiff files. |
| [environment.yml](./src/environment.yml) | Conda environment to run the geoprocessing scripts. Core includes OSWGeo GDAL and Python |


<p align="right">(<a href="#indexerd-md-top">back to top</a>)</p>

# Setup

Scripts were intended to be used in a Windows machine with conda installed.

To install Miniconda as described in the [conda website](https://docs.anaconda.com/free/miniconda/)

create the environment

```powershell
(base) conda env create -f environment.yml
```

Activate the environment

```powershell
conda activate map
```


Call the desired script, for example

```powershell
(map).\name_paths.ps1
(map) python check_files.py

```

# Roadmap

This section presents a simplified view of the roadmap and knwon issues.

For more details, see the [open issues](https://github.com/FSLobao/RF.Fusion/issues)

* [ ] Test geo naming convention with OpenElevation
* [ ] Include tile size parameter to create smaller tiles and optimize server performance
  
<p align="right">(<a href="#indexerd-md-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
# Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

<p align="right">(<a href="#indexerd-md-top">back to top</a>)</p>

<!-- LICENSE -->
# License

Distributed under the GNU General Public License (GPL), version 3. See [`LICENSE.txt`](../../LICENSE).

For additional information, please check <https://www.gnu.org/licenses/quick-guide-gplv3.html>

This license model was selected with the idea of enabling collaboration of anyone interested in projects listed within this group.

It is in line with the Brazilian Public Software directives, as published at: <https://softwarepublico.gov.br/social/articles/0004/5936/Manual_do_Ofertante_Temporario_04.10.2016.pdf>

Further reading material can be found at:

* <http://copyfree.org/policy/copyleft>
* <https://opensource.stackexchange.com/questions/9805/can-i-license-my-project-with-an-open-source-license-but-disallow-commercial-use>
* <https://opensource.stackexchange.com/questions/21/whats-the-difference-between-permissive-and-copyleft-licenses/42#42>

<p align="right">(<a href="#indexerd-md-top">back to top</a>)</p>

<!-- ACKNOWLEDGMENTS -->
## References

* [Conda Cheat Sheet](https://docs.conda.io/projects/conda/en/4.6.0/_downloads/52a95608c49671267e40c689e0bc00ca/conda-cheatsheet.pdf)
* [Readme Template](https://github.com/othneildrew/Best-README-Template)

<p align="right">(<a href="#indexerd-md-top">back to top</a>)</p>
