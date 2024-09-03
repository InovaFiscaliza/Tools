function [vis,visprofile,dist,h,lattrk,lontrk] = los_from_tiles(tile_set,lat1,lon1,lat2,lon2)
%LOS_FROM_TILES Expansion of LOS2 function to work with a tile repository
    
    % Test if tile set path is accessible
    [Z,R] = readgeoraster(tile_set,"OutputType","double");

    [vis,visprofile,dist,h,lattrk,lontrk] = los2(Z,R,lat1,lon1,lat2,lon2);

end