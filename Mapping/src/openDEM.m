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
        function obj = clean_file_names(obj)
            %CLEAN_FILE_NAMES Remove unwanted path from tile file names
            %   Tiles are supposed to be stored in the same directory of the json index. The path to the directory is not needed in the obj.tile_index va
            for i = 1:length(obj.tile_index)
                obj.tile_index{i} = strrep(obj.tile_index{i},'\','/');
                
            end
        end
        
        function tilename = get_tile_name(obj,lat,lon)
            %GET_TILE_NAME Summary of this method goes here
            %   Detailed explanation goes here
                        % define the hemisfere according to the latitude signal of the minimum latitude
            if latlim(1) < 0
                parallel_hemisphere = "S";
            else
                parallel_hemisphere = "N";
            end

            % define the meridian according to the longitude signal of the minimum longitude
            if lonlim(1) < 0
                meridian_hemisphere = "W";
            else
                meridian_hemisphere = "E";
            end

            % compose a string in the format "PhDDMhEEE", where Ph is the hemisphere, DD is the integer part of the latitude, M is the hemisphere of the meridian, EE is the integer part of the longitude
            tile_name_segment = sprintf("%s%02d%s%03d",parallel_hemisphere,floor(latlim(2)),meridian_hemisphere,floor(lonlim(1)));

            tile_matching = cellfun( @(x) contains(x,tile_name_segment), tile_file_names );
            tilename = find(tile_matching, 1 );

        end

        function obj = get_tiles(obj)
            %OPENDEM Construct an instance of this class
                        % get maximum and minimum latitude and longitude
            lat = [source_poi.lat target_poi.lat];
            lon = [source_poi.lon target_poi.lon];

            latmin = floor(min(lat));
            latmax = floor(max(lat));
            lonmim = floor(min(lon));
            lonmax = floor(max(lon));
            
            tiles_required = (latmax - latmin + 1) * (lonmax - lonmin + 1);

            if tiles_required > obj.max_tiles
                error(sprintf("%d tiles required to cover the POI. Maximum number of tiles is %d",tiles_required,obj.max_tiles));
            end

            % get the tile names
            tile_set = {};
            for lat = latmin:1:latmax
                for lon = lonmin:1:lonmax
                    tile_name = get_tile_name(lat,lon);
                    tile_path = obj.tile_index(tile_name);
                    if ~isfile(tile_path)
                        error(sprintf("Tile %s not found",tile_name));
                    end
                    tile_set{end+1} = tile_path;
                end
            end

            % check if the area covered by the POI is less than 2 degrees
            if ((latlim(2)-latlim(1)) > 2 || (lonlim(2)-lonlim(1)) > 2)
                warning("Area covered by the POI is too large");
                fnc_ok = false;
            end

            % check if maximum latitude has the same interger part as the minimum latitude
            if floor(latlim(1)) ~= floor(latlim(2))
                require_two_parallel_degrees = true;
            end

            if floor(lonlim(1)) ~= floor(lonlim(2))
                require_two_meridian_degrees = true;
            end


            try 
                [ZNW,RNW] = readgeoraster(NWTile,"OutputType","double");
                latlimNW = RNW.LatitudeLimits;
                lonlimNW = RNW.LongitudeLimits;
            catch
                error("NW Tile not found");
            end

            try 
                [ZSW,RSW] = readgeoraster(SWTile,"OutputType","double");
                latlimSW = RSW.LatitudeLimits;
                lonlimSW = RSW.LongitudeLimits;
            catch
                error("SW Tile not found");
            end

            try 
                [ZNE,RNE] = readgeoraster(NETile,"OutputType","double");
                latlimNE = RNE.LatitudeLimits;
                lonlimNE = RNE.LongitudeLimits;
            catch
                error("NE Tile not found");
            end

            try 
                [ZSE,RSE] = readgeoraster(SETile,"OutputType","double");
                latlimSE = RSE.LatitudeLimits;
                lonlimSE = RSE.LongitudeLimits;
            catch
                error("SE Tile not found");
            end


            [ZSW,RSW] = readgeoraster(RJtilepath2,"OutputType","double");
            latlimSW = RSW.LatitudeLimits;
            lonlimSW = RSW.LongitudeLimits;

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
                    
                    clean_file_names();

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