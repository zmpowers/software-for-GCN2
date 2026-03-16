// --- USER SETTINGS ---
pixelDistance = 1; 
micronValue = 0.325; //0.325 for 20x, 0.1625 for 40x   
unit = "um";
scaleBarSize = 25; 
cropSizeMicrons = 80; 

// LUT VALUES
c1Min = 101; c1Max = 4000;  // DAPI, 405
c2Min = 101; c2Max = 4000;  // phalloidin, 488
c3Min = 101; c3Max = 4000;  // dsRed Salmonella, 594
c4Min = 101; c4Max = 4000;  // ATF4, 647
// ---------------------

run("Close All"); 
inputDir = getDirectory("Choose the folder containing your images"); 
outputDir = getDirectory("Choose a destination folder for crops"); 
list = getFileList(inputDir); 

// Create folders
tifDir = outputDir + "TIF_Channels" + File.separator;
pngCompDir = outputDir + "PNG_Composites" + File.separator;
pngIndivDir = outputDir + "PNG_Individual_Channels" + File.separator;

if (!File.exists(tifDir)) File.makeDirectory(tifDir);
if (!File.exists(pngCompDir)) File.makeDirectory(pngCompDir);
if (!File.exists(pngIndivDir)) File.makeDirectory(pngIndivDir);

logFile = outputDir + "LUT_Parameters_Log.txt";
if (!File.exists(logFile)) {
    // --- CHANGE 1: Added Crop Headers to the log file ---
    File.append("Set_Name\tC1_Min\tC1_Max\tC2_Min\tC2_Max\tC3_Min\tC3_Max\tC4_Min\tC4_Max\tCrop_X\tCrop_Y\tCrop_W\tCrop_H", logFile);
} // this section must be changed to match channel naming convention. 

for (i = 0; i < list.length; i++) {
    if (indexOf(list[i], "C1.tif") >= 0) {
        
        baseName = replace(list[i], "C1.tif", ""); 
        
        // --- STEP 1: SILENT SETUP ---
        setBatchMode(true); 
        for (c = 1; c <= 4; c++) {
            targetFile = inputDir + baseName + "C" + c + ".tif";
            if (File.exists(targetFile)) open(targetFile);
        }

        run("Images to Stack", "method=[Copy (center)] name=TempStack title=[] use");
        run("Stack to Hyperstack...", "order=xyczt(default) channels=4 slices=1 frames=1 display=Composite");
        run("Set Scale...", "distance="+pixelDistance+" known="+micronValue+" unit="+unit);
        
        // Apply LUTs
        Stack.setChannel(1); run("Blue");    setMinAndMax(c1Min, c1Max);
        Stack.setChannel(2); run("Green");   setMinAndMax(c2Min, c2Max);
        Stack.setChannel(3); run("Red");     setMinAndMax(c3Min, c3Max);
        Stack.setChannel(4); run("Magenta"); setMinAndMax(c4Min, c4Max);
        
        // --- STEP 2: INTERACTIVE CROP ---
        setBatchMode("exit and display"); // Exit batch mode to show the crop window
        selectWindow("TempStack");
        
        cropSizePixels = (cropSizeMicrons / micronValue) * pixelDistance;
        makeRectangle(10, 10, cropSizePixels, cropSizePixels);
        setTool("rectangle"); 
        
        waitForUser("Position Crop Box", "DRAG the " + cropSizeMicrons + "um box.\nClick OK when ready.");
        
        // --- CHANGE 2: Capture coordinates BEFORE cropping ---
        getSelectionBounds(cropX, cropY, cropW, cropH);

        run("Crop");

        // --- STEP 3: SILENT EXPORTING ---
        setBatchMode(true); // Re-enter batch mode to hide the "flashing" exports
        
        // Export Composite
        run("Duplicate...", "duplicate"); 
        rename("ForPNG");
        run("Scale Bar...", "width="+scaleBarSize+" height=4 font=14 color=White background=None location=[Lower Right] bold overlay");
        run("Flatten");
        saveAs("Png", pngCompDir + baseName + "Composite.png");
        close(); 
        if (isOpen("ForPNG")) { selectWindow("ForPNG"); close(); }

        // Export Individual Channels
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
                close(); 
                close(); 
            }
        }
        
        // Log Entry
        // --- CHANGE 3: Append coordinates to the log entry string ---
        logEntry = "\n" + baseName + "\t" + c1Min + "\t" + c1Max + "\t" + c2Min + "\t" + c2Max + "\t" + c3Min + "\t" + c3Max + "\t" + c4Min + "\t" + c4Max + "\t" + cropX + "\t" + cropY + "\t" + cropW + "\t" + cropH;
        File.append(logEntry, logFile);
        
        setBatchMode(false); // End batch mode for this loop iteration
    }
}
setBatchMode(false); 
print("Process Complete with fixed " + cropSizeMicrons + "um crops! (Coordinates Logged)");