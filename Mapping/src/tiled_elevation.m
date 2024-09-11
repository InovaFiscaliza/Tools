classdef tiled_elevation < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here

    properties
        source_points
        target_points
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

    methods
        function obj = tiled_elevation(source_points,target_points)
            %TILED_ELEVATION Construct an instance of this class
            %   Detailed explanation goes here
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


            obj.Property1 = inputArg1 + inputArg2;
        end

        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

function [vis,visprofile,dist,h,lattrk,lontrk] = los_from_tiles(tile_set,lat1,lon1,lat2,lon2)
%LOS_FROM_TILES Expansion of LOS2 function to work with a tile repository
    
    % Test if tile set path is accessible
    [Z,R] = readgeoraster(tile_set,"OutputType","double");

    [vis,visprofile,dist,h,lattrk,lontrk] = los2(Z,R,lat1,lon1,lat2,lon2);

end