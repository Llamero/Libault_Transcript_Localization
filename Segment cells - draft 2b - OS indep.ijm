blur = 20; //Amount to blur calfluor to smooth borders
min_tolerance = 100; //Watershed tolerance
max_tolerance = 1000;
tolerance_steps = 10; //Number of tolerance steps to test
local_threshold_area_fraction = 5; //Fractional width/height of total image to test for a local threshold to speed up the analysis

close("*");
setBatchMode(true);
if(isOpen("Results")){
	selectWindow("Results");
	run("Close");
}

while(true){
	path = File.openDialog("Select calcofluor image to segment.");
	nuc_path = File.openDialog("Select the matching nuclear mask.");
	trans_path = File.openDialog("Select the matching transcript coordinate list.");
	open(path);
	i = getTitle();
	
	//Show GUI to have user choose filter settings
	Dialog.create("Select Segmentation Parameters");
	Dialog.addNumber("Image Gaussian blur radius (lower values = increased segmentation)", blur);
	Dialog.addNumber("Test area fraction", local_threshold_area_fraction);
	Dialog.addNumber("Minimum watershed tolerance", min_tolerance);
	Dialog.addNumber("Maximum watershed tolerance", max_tolerance);
	Dialog.addNumber("Number of tolerance steps", tolerance_steps);
	Dialog.show();
	print("--------------------------------------------------------");
	print(path);
	
	//Get GUI settings
	blur = Dialog.getNumber();
	local_threshold_area_fraction = Dialog.getNumber();
	min_tolerance = Dialog.getNumber();
	max_tolerance = Dialog.getNumber();
	tolerance_steps = Dialog.getNumber();
	
	morphologicalSegmentation(i);
	close("*");
	if(!getBoolean("Would you like to process another image?")) break;	
}
showMessage("Reminder: save the results table!");
setBatchMode("exit and display");
	

function morphologicalSegmentation(i){
	//Simplify the local threshold test by having the user specify an sub region
	selectWindow(i);
	run("Select None");
	getDimensions(width, height, channels, slices, frames);
	r_w = round(width/local_threshold_area_fraction);
	r_h = round(height/local_threshold_area_fraction);
	x=round(width/2-r_w/2);
	y=round(height/2-r_h/2);
	makeRectangle(x, y, r_w, r_h);
	setBatchMode("show");
	waitForUser("Select subregion to test for segmentation");
	setBatchMode("hide");
	
	//Run a series of local thresholds to allow the user to find the optimal threshold
	selectWindow(i);
	run("Duplicate...", "title=[Image]");
	selectWindow("Image");
	run("Duplicate...", "title=[Threshold]");
	selectWindow("Threshold");
	run("Gaussian Blur...", "sigma=" + blur);
	setBatchMode("show");
	run("Morphological Segmentation");
	while(!isOpen("Morphological Segmentation"));
	wait(1000);
	print(2);
	call("inra.ijpb.plugins.MorphologicalSegmentation.setInputImageType", "border");
	call("inra.ijpb.plugins.MorphologicalSegmentation.setDisplayFormat", "Watershed lines");
	t_step = (max_tolerance-min_tolerance)/(tolerance_steps-1);
	for(t = min_tolerance; t <= max_tolerance; t += t_step){
		print("\\Clear");
		tolerance = round(t);
		showStatus("!Testing local radius: " + t);
		selectWindow("Morphological Segmentation");
		call("inra.ijpb.plugins.MorphologicalSegmentation.segment", "tolerance=" + tolerance, "calculateDams=true", "connectivity=4");
		while(true){
			status = getInfo("log");
			if(indexOf(status, "Whole plugin took") > 0) break;
		}
		wait(3000);
		call("inra.ijpb.plugins.MorphologicalSegmentation.createResultImage");
		while(!isOpen("Threshold-watershed-lines")) wait(500);
		selectWindow("Image");
		run("Duplicate...", "title=[Image1]");
		setMetadata("Label", t);
		if(isOpen("Tolerance Stack")){
			run("Concatenate...", "  title=[Tolerance Stack] open image1=[Tolerance Stack] image2=[Threshold-watershed-lines] image3=[-- None --]");
			run("Concatenate...", "  title=[Image Stack] open image1=[Image Stack] image2=[Image1] image3=[-- None --]");
		}
		else{
			selectWindow("Threshold-watershed-lines");
			rename("Tolerance Stack");
			selectWindow("Image1");
			rename("Image Stack");
		}
	}
	selectWindow("Morphological Segmentation");
	run("Close");
	close("Image");

	//Show threshold results to user
	selectWindow("Tolerance Stack");
	run("Invert", "stack");
	if(getInfo("os.name") == "Windows") run("Erode", "stack");
	else run("Dilate", "stack");
	selectWindow("Image Stack");
	run("8-bit");
	run("Merge Channels...", "c2=[Image Stack] c6=[Tolerance Stack] create keep ignore");
	selectWindow("Merged");
	setBatchMode("show");
	waitForUser("Select the optimal threshold radius");

	//Retrieve the local threshold value
	selectWindow("Merged");
	Stack.getPosition(dummy, dummy, frame);
	close("Merged");
	selectWindow("Image Stack");
	setSlice(frame);
	meta = getMetadata("Label");
	run("Duplicate...", "title=[Local Test Mask]");
	close("Threshold Stack");
	segmentation_threshold = parseFloat(meta);
	setResult("Calcofluor path", nResults, path);
	setResult("Nucleus mask path", nResults-1, nuc_path);
	setResult("Transcript list path", nResults-1, trans_path);
	setResult("Segmentation Threshold", nResults-1, segmentation_threshold);
	setResult("Image blur", nResults-1, blur);
	updateResults();
}
