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
        tile_index
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

            latlim = [min(lat) max(lat)];
            lonlim = [min(lon) max(lon)];
            
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
            %   receive a datasource and load the associated index file

            if nargin == 0
                obj.method = obj.MATHWORKS_SERVICE;
            elseif ~endsWith(varargin{1},".json")
                obj.method = obj.TILE_SERVICE;
                try
                    str=fileread(datasouce);
                    json_index=jsondecode(str);
                    obj.tile_index=extractfield(obj.json_index,'file');
                catch
                    error("Json tile index file not found");
                end
            elseif contains(varargin{1},"http")
                obj.method = obj.PUBLIC_SERVICE;
                % TODO: implement test of the public service
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