
# Test different methos for Line of Sight extraction from a tile repository
```matlab
clear();
```

Test control

```matlab
tilepath="D:\fabdem\S23W044_FABDEM_V1-2.tif";

lat1 = -23;
lon1 = -44;
lat2 = -22;
lon2 = -43;
```

Display sample

```matlab
[Z,R] = readgeoraster(tilepath,"OutputType","double");
latlim = R.LatitudeLimits;
lonlim = R.LongitudeLimits;
usamap(latlim,lonlim)
geoshow(Z,R,"DisplayType","surface")
demcmap(Z)
```

![](./LOS_test_media//)

Measure the execution time for los2 within the live script

```matlab
tic
[Z,R] = readgeoraster(tilepath,"OutputType","double");
[vis,visprofile,dist,h,lattrk,lontrk] = los2(Z,R,lat1,lon1,lat2,lon2);
toc
```

```matlabTextOutput
Elapsed time is 0.547781 seconds.
```

Measure the execution time for los2 within a function

```matlab
f = @() los_from_tiles(tilepath,lat1,lon1,lat2,lon2)
```

```matlabTextOutput
f = function_handle with value:
    @()los_from_tiles(tilepath,lat1,lon1,lat2,lon2)

```

```matlab
timeit(f)
```

```matlabTextOutput
ans = 0.5353
```


