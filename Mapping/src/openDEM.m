classdef openDEM < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    properties (Constant)
        % Constants
        MATHWORKS_SERVICE = 1; 
        TILE_SERVICE = 2;
        PUBLIC_SERVICE = 3;
    end
    properties
        method
        service_url = "https://fiscalizacao.anatel.gov.br/";
        tile_path
        tile_index
        max_tiles = 4;
        source_poi
        target_poi
        Z
        R
        NWTile
        SWTile
        NETile
        SETile
        ZNW
        RNW
        ZSW
        RSW
        ZNE
        RNE
        ZSE
        RSE
        Z
        R
    end

    methods (Access = private)
        function clean_name = clean_file_names(dirty_name)
            %CLEAN_FILE_NAMES Remove unwanted path from tile file names
            %   Tiles are supposed to be stored in the same directory of the json index. The path to the directory is not needed in the obj.tile_index va
            
            % find the position of the last slash or backslash in the string
            lastdot_pos = find(dirty_name == '\', 1, 'last');
            if isempty(lastdot_pos)
                lastdot_pos = find(dirty_name == '/', 1, 'last');
                if isempty(lastdot_pos)
                    clean_name = dirty_name;
                end
            end
            clean_name = dirty_name(lastdot_pos + 1 : end);
        end

        
        function tile_filename = get_tile_name(obj,lat,lon)
            %GET_TILE_NAME Get the name of the tile that has the reference in a given latitude and longitude
            %   latitude and longitude must be integers that represente the left bottom corner of the tile (minimum latitude and longitude)

            % compose a string in the format "PhDDMhEEE", where Ph is the hemisphere, DD is the integer part of the latitude, M is the hemisphere of the meridian, EE is the integer part of the longitude
            if lat < 0
                parallel_hemisphere = "S";
            else
                parallel_hemisphere = "N";
            end

            if lon < 0
                meridian_hemisphere = "W";
            else
                meridian_hemisphere = "E";
            end

            tile_name_segment = sprintf("%s%02d%s%03d",parallel_hemisphere,lat,meridian_hemisphere,lon);

            % search for the tile name in the tile index and return the full name
            tile_matching = cellfun( @(x) contains(x,tile_name_segment), obj.tile_index );
            
            index = find(tile_matching, 1 );
            if isempty(index)
                tile_filename = "";
            else
                tile_filename = strcat(tile_path,'/',obj.tile_index(index));
            end

        end

        function obj = get_tiles(obj)
            %GET_TILES private method to get the tiles from POI
            %   The method will get the tiles that cover the area between the source and target POI, and store them in the object properties

            % get reference coordinates and sizes from the POI
            POI_lat = [obj.source_poi.lat obj.target_poi.lat];
            POI_lon = [obj.source_poi.lon obj.target_poi.lon];

            latmin = floor(min(POI_lat));
            latmax = floor(max(POI_lat));
            lonmim = floor(min(POI_lon));
            lonmax = floor(max(POI_lon));
            
            parallel_size = latmax - latmin + 1;
            meridian_size = lonmax - lonmin + 1;
            tiles_required = parallel_size * meridian_size;

            % validate if the number of tiles required is within the limit
            if tiles_required > obj.max_tiles
                error("%d tiles required to cover the POI. Maximum number of tiles is %d",tiles_required,obj.max_tiles);
            end

            % create a cell array to store the tile names from the object tile index
            tile_set = cell(parallel_size,meridian_size);

            for lat = latmin:1:latmax
                for lon = lonmin:1:lonmax
                    iLat = lat - latmin + 1;
                    iLon = lon - lonmin + 1;
                    tile_set{iLat,ilon} = get_tile_name(lat,lon);
                end
            end

            % loop through the tile set until the first tile is found
            for ilat = 1:parallel_size
                for ilon = 1:meridian_size
                    if ~isempty(tile_set{ilat,ilon})
                        found = true;
                        break;
                    end
                end
                if found
                    break;
                end
            end

            % alocate the memory to the complet tile matrix
            [Zf,Rf] = readgeoraster(tile_set{ilat,ilon},"OutputType","double");
            
            % create a matrix to store the tiles with size equal to the sum of the sizes of the tiles
            tile_size = size(Zf);
            obj.Z = zeros(tile_size(1) * parallel_size, tile_size(2) * meridian_size, 'double');
            Rarray = cell(parallel_size,meridian_size);

            % Copy the tile already loaded to the matrix considering it's position as defined by the ilat and ilon indexes
            obj.Z{((ilat-1)*tile_size(1))+1:((ilat-1)*tile_size(1))+tile_size(1),((ilon-1)*tile_size(2))+1:((ilon-1)*tile_size(2))+tile_size(2)} = Zf;
            Rarray{ilat,ilon} = Rf;

            % Keep the loop through to load the remaining tiles
            for jlat = ilac:parallel_size
                for jlon = ilon:meridian_size
                    if isempty(tile_set{jlat,jlon})
                        continue;
                    end
                    [Zf,Rf] = readgeoraster(tile_set{jlat,jlon},"OutputType","double");
                    obj.Z(((jlat-1)*tile_size(1))+1:((jlat-1)*tile_size(1))+tile_size(1),((jlon-1)*tile_size(2))+1:((jlon-1)*tile_size(2))+tile_size(2)) = Zf;
                    Rarray{jlat,jlon} = Rf;
                end
            end

            % ! NEED TO MERGE THE Rarray into a single obj.R
        end
    end

    methods
        function obj = openDEM(varargin)
            %OPENDEM Construct an instance of this class
            %   Default method is the MathWorks service; if no parameters are passed
            %   If a JSON file is passed, the tile service is used
            %   If a URL is passed, the public service is used
            %   Optional parameters: max_tiles, maximum number of tiles to be cached, default is 4

            if nargin == 0
                obj.method = obj.MATHWORKS_SERVICE;
                return;
            if nargin > 1
                if rem(nargin, 2) == 0
                    error("Wrong number of parameters. Optional parameters must come in pairs, with label and value");
                end
                i = 2;
                while i < nargin
                    switch varargin{i}
                        case 'max_tiles'
                            obj.max_tiles = varargin{i + 1};
                        otherwise
                            error(strcat("Optional parameter '", varargin{i},"' not recognized"));
                    end
                    i = i + 2;
                end
            end

            if ~endsWith(varargin{1},".json")
                obj.method = obj.TILE_SERVICE;
                try
                    lastdot_pos = find(YourString == '\', 1, 'last');
                    if isempty(lastdot_pos)
                        lastdot_pos = find(YourString == '/', 1, 'last');
                        if isempty(lastdot_pos)
                            error("Invalid path to tile json index file. Please provide full path");
                        end
                    end
                    obj.tile_path = YourString(1 : lastdot_pos - 1);

                    str=fileread(varargin{1});
                    json_index=jsondecode(str);
                    obj.tile_index=extractfield(json_index,'file');
                    
                    cellfun( @(x) clean_file_names(x), obj.tile_index );

                catch
                    error("Json tile index file not found");
                end
            elseif contains(varargin{1},"http")
                obj.method = obj.PUBLIC_SERVICE;
                % TODO: implement test of the public service before continuing
            else
                error("Invalid data source");
            end
        end

        function fnc_ok = setPOI(obj,source_poi,target_poi)
            %setPOI Set the source and target points of interest
            % POI, Point of Interest, is a structure with the following fields:
            %   - lat: latitude
            %   - lon: longitude
            % Tiles will and LOS will be cached using the connecting points from source to target

            % Check if source and target POI are valid
            arguments
                obj
                source_poi struct
                target_poi struct
            end
            
            if (~isfield(source_poi,"lat") || ~isfield(source_poi,"lon") || ~(length(source_poi) >= 1))
                warning("Invalid source POI");
                fnc_ok = false;
            end

            if (~isfield(target_poi,"lat") || ~isfield(target_poi,"lon") || ~(length(target_poi) >= 1))
                warning("Invalid target POI");    
                fnc_ok = false;
            end

            obj.source_poi = source_poi;
            obj.target_poi = target_poi;

            fn_ok = true;
        end
    end
end

function [vis,visprofile,dist,h,lattrk,lontrk] = los_from_tiles(tile_set,lat1,lon1,lat2,lon2)
%LOS_FROM_TILES Expansion of LOS2 function to work with a tile repository
    
    % Test if tile set path is accessible
    [Z,R] = readgeoraster(tile_set,"OutputType","double");

    [vis,visprofile,dist,h,lattrk,lontrk] = los2(Z,R,lat1,lon1,lat2,lon2);

end