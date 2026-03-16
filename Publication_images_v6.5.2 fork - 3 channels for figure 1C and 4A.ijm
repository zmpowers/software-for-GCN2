// --- USER SETTINGS ---
pixelDistance = 1; 
micronValue = 0.325;    // set to 20x, for 40x use 0.1625
unit = "um";
scaleBarSize = 25; 
cropSizeMicrons = 80; 



// LUT VALUES (Min, Max)
c1Min = 89; c1Max = 1325;  // DAPI, 405
c2Min = 210; c2Max = 4982; // Phalloidin, 488
c3Min = 302; c3Max = 825;  // DsRed Typhi, 594
c4Min = 125; c4Max = 269;  // ATF4, 647
// ---------------------

run("Close All"); 
inputDir = getDirectory("Choose the folder containing your images"); 
outputDir = getDirectory("Choose a destination folder for crops"); 
list = getFileList(inputDir); 

// Create the 4 distinct output folders
tifDir = outputDir + "TIF_Channels" + File.separator;
pngCompDir = outputDir + "PNG_Composites" + File.separator;
pngTripleDir = outputDir + "PNG_DAPI_Actin_Bacteria" + File.separator; 
pngIndivDir = outputDir + "PNG_Individual_Channels" + File.separator;

if (!File.exists(tifDir)) File.makeDirectory(tifDir);
if (!File.exists(pngCompDir)) File.makeDirectory(pngCompDir);
if (!File.exists(pngTripleDir)) File.makeDirectory(pngTripleDir);
if (!File.exists(pngIndivDir)) File.makeDirectory(pngIndivDir);

logFile = outputDir + "LUT_Parameters_Log.txt";
if (!File.exists(logFile)) {
    File.append("Set_Name\tC1_Min\tC1_Max\tC2_Min\tC2_Max\tC3_Min\tC3_Max\tC4_Min\tC4_Max", logFile);
} // identify channels and group by image based on naming convention

// Start processing loop
for (i = 0; i < list.length; i++) {
    if (indexOf(list[i], "C1.tif") >= 0) {
        
        baseName = replace(list[i], "C1.tif", ""); 
        
        // Open the 4 channels
        for (c = 1; c <= 4; c++) {
            targetFile = inputDir + baseName + "C" + c + ".tif";
            if (File.exists(targetFile)) open(targetFile);
        }

        // Create Stack and Hyperstack
        run("Images to Stack", "method=[Copy (center)] name=TempStack title=[] use");
        run("Stack to Hyperstack...", "order=xyczt(default) channels=4 slices=1 frames=1 display=Composite");
        run("Set Scale...", "distance="+pixelDistance+" known="+micronValue+" unit="+unit);
        
        // Apply LUTs
        Stack.setChannel(1); run("Blue");    setMinAndMax(c1Min, c1Max);
        Stack.setChannel(2); run("Green");   setMinAndMax(c2Min, c2Max);
        Stack.setChannel(3); run("Red");     setMinAndMax(c3Min, c3Max);
        Stack.setChannel(4); run("Magenta"); setMinAndMax(c4Min, c4Max);
        
        // --- CROP BOX INTERACTION ---
        setBatchMode(false); // Force Fiji to show the window
        selectWindow("TempStack");
        updateDisplay();
        
        cropSizePixels = (cropSizeMicrons / micronValue) * pixelDistance;
        makeRectangle(10, 10, cropSizePixels, cropSizePixels);
        setTool("rectangle"); 
        
        waitForUser("Position Crop Box", "DRAG the " + cropSizeMicrons + "um box to your area of interest.\nClick OK when ready.");
        
        run("Crop");

        // --- EXPORT 1: FULL 4-CHANNEL COMPOSITE ---
        run("Duplicate...", "title=FullMerge duplicate");
        run("Scale Bar...", "width="+scaleBarSize+" height=4 font=14 color=White background=None location=[Lower Right] bold overlay");
        run("Flatten");
        saveAs("Png", pngCompDir + baseName + "Composite_Full.png");
        close(); 
        if (isOpen("FullMerge")) { selectWindow("FullMerge"); close(); }

        // --- EXPORT 2: 3-CHANNEL COMPOSITE (NEW FOLDER) ---
        selectWindow("TempStack");
        run("Duplicate...", "title=TripleMerge duplicate channels=1-3");
        run("Scale Bar...", "width="+scaleBarSize+" height=4 font=14 color=White background=None location=[Lower Right] bold overlay");
        run("Flatten");
        saveAs("Png", pngTripleDir + baseName + "DAPI_Actin_Bacteria.png");
        close(); 
        if (isOpen("TripleMerge")) { selectWindow("TripleMerge"); close(); }

        // --- EXPORT 3: INDIVIDUALS & TIFS ---
        selectWindow("TempStack");
        run("Split Channels");
        for (c = 1; c <= 4; c++) {
            chanName = "C" + c + "-TempStack";
            if (isOpen(chanName)) {
                selectWindow(chanName);
                saveAs("Tiff", tifDir + baseName + "C" + c + "_Cropped.tif");
                run("Scale Bar...", "width="+scaleBarSize+" height=4 font=14 color=White background=None location=[Lower Right] bold overlay");
                run("Flatten");
                saveAs("Png", pngIndivDir + baseName + "C" + c + "_Individual.png");
                close(); // close flattened
                close(); // close tif window
            }
        }
        
        // Append to Log
        logEntry = "\n" + baseName + "\t" + c1Min + "\t" + c1Max + "\t" + c2Min + "\t" + c2Max + "\t" + c3Min + "\t" + c3Max + "\t" + c4Min + "\t" + c4Max;
        File.append(logEntry, logFile);
    }
}
print("Process Complete! All images saved in 4 sub-folders.");