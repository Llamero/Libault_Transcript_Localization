close("\\Others");
setBatchMode(true);
setBatchMode("hide");
local_threshold_area_fraction = 5; //Fractional width/height of total image to test for a local threshold to speed up the analysis
min_local_threshold_radius = 3; //Minimum local threshold radius to test
max_local_threshold_radius = 100; //Maximum local threshold radius to test
local_threshold_radius_step_factor = 1.4; //Factor to increment local threshold radius by
min_median_radius = 5; //Minimum local threshold radius to test
max_median_radius = 30; //Maximum local threshold radius to test
median_step = min_median_radius; //Increment step size for median filter
//filter_label = newArray("Area", "Mean", "Sobel", "StdDev"); //List of filters to run

path = File.openDialog("Select file to process.");
open(path);
i = getTitle();

//Show GUI to have user choose filter settings
local_thresholds = newArray("Bernsen", "Contrast", "Median", "MidGrey", "Niblack", "Otsu", "Phansalkar");
analysis_filters = newArray("Area", "Mean", "StdDev", "Mode", "Min", "Max", "Perim.", "Circ.", "Median", "AR", "Round", "Solidity");
default_filters = newArray(true, true, true, false, false, false, false, true, false, false, false, false);
Dialog.create("Select Filters");
Dialog.addMessage("Auto Local Threshold", 14);
Dialog.addNumber("Test area fraction", local_threshold_area_fraction);
Dialog.addChoice("Algorithm", local_thresholds, local_thresholds[local_thresholds.length-1]);
Dialog.addNumber("Minimum radius", min_local_threshold_radius);
Dialog.addNumber("Maximum radius", max_local_threshold_radius);
Dialog.addNumber("Step factor", local_threshold_radius_step_factor);
Dialog.addMessage("\nMedian Filter", 14);
Dialog.addNumber("Minimum radius", min_median_radius);
Dialog.addNumber("Maximum radius", max_median_radius);
Dialog.addNumber("Step size", median_step);
Dialog.addMessage("\nParticle Analysis Filters", 14);
Dialog.addCheckboxGroup(4, 3, analysis_filters, default_filters);
Dialog.show();
print("--------------------------------------------------------");
print(path);

//Get GUI settings
local_threshold_area_fraction = Dialog.getNumber();
threshold_algorithm = Dialog.getChoice();
min_local_threshold_radius = Dialog.getNumber();
max_local_threshold_radius = Dialog.getNumber();
local_threshold_radius_step_factor = Dialog.getNumber();
min_median_radius = Dialog.getNumber();
max_median_radius = Dialog.getNumber();
median_step = Dialog.getNumber();
filter_count = 0;
for(a=0; a<default_filters.length; a++){ //Count number of filters
	default_filters[a] = Dialog.getCheckbox();
	if(default_filters[a]) filter_count++;
}
filter_label = newArray(filter_count);
filter_values = newArray(filter_count);
filter_count = 0;
for(a=0; a<default_filters.length; a++){
	if(default_filters[a]) filter_label[filter_count++] = analysis_filters[a];
}

local_threshold_radius = 0;
median_radius = 0;
run("Set Measurements...", "area mean standard min center perimeter shape median redirect=None decimal=3");
//findRoot(i);
while(local_threshold_radius < 1) local_threshold_radius = localThreshold(i);
while(median_radius < 1) median_radius = medianRadius("Local Test Mask");
filter_values = filterStack(filter_values);
filter_string = "Filter values - local threshold: " + local_threshold_radius + ", median: " + median_radius;
for(a=0; a<filter_values.length; a++){
	filter_string += ", " + filter_label[a] + ": " + filter_values[a];
}
print(filter_string);
processImage(i, local_threshold_radius, median_radius, filter_values);


setBatchMode("exit and display");
exit();


selectWindow(i);
showStatus("Applying local radius: " + local_threshold_radius);
run("Select None");
run("Duplicate...", "title=[Nucleus Mask]");
selectWindow("Nucleus Mask");
resetMinAndMax();
run("8-bit");
run("Auto Local Threshold", "method=" + threshold_algorithm + " radius=" + local_threshold_radius + " parameter_1=0 parameter_2=0 white");
run("Median...", "radius=" + median_radius);
setBatchMode("exit and display");

function findRoot(i){
	selectWindow(i);
	run("Select None");
	run("Duplicate...", "title=[Analysis area]");
	selectWindow("Analysis area");
	setAutoThreshold("Default dark");
	setOption("BlackBackground", false);
	run("Threshold...");
	setBatchMode("show");
	waitForUser("Set threshold for the region you want to analyze");
	setBatchMode("hide");
	selectWindow("Threshold");
	run("Close");
	run("Convert to Mask");
	run("Fill Holes");
	run("Analyze Particles...", "  show=[Count Masks] display clear");
	max_area = -1;
	for(row=0; row<nResults; row++){
		area = getResult("Area", row);
		if(area > max_area) max_area = area;
	}
	close("Count Masks of Analysis area");
	selectWindow("Analysis area");
	run("Analyze Particles...", "size=" + max_area + "-Infinity show=Masks clear");
	close("Analysis area");
	selectWindow("Mask of Analysis area");
	rename("Analysis Area");
//	run("Create Selection");
//	selectWindow(i);
//	run("Restore Selection");
//	run("Clear Outside");
//	run("Select None");
}

function localThreshold(i){
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
	waitForUser("Select subregion to test for local thresholds");
	setBatchMode("hide");
	
	//Run a series of local thresholds to allow the user to find the optimal threshold
	selectWindow(i);
	run("Duplicate...", "title=[Threshold]");
	selectWindow("Threshold");
	resetMinAndMax();
	run("8-bit");
	for(r = min_local_threshold_radius; r <= max_local_threshold_radius; r *= local_threshold_radius_step_factor){
		radius = round(r);
		showStatus("!Testing local radius: " + r);
		selectWindow("Threshold");
		run("Duplicate...", "title=[Threshold " + radius + "]");
		selectWindow("Threshold");
		run("Duplicate...", "title=[Image " + radius + "]");
		selectWindow("Threshold " + radius);
		setMetadata("Label", radius);
		run("Auto Local Threshold", "method=Phansalkar radius=" + radius + " parameter_1=0 parameter_2=0 white");
		if(isOpen("Threshold Stack")){
			run("Concatenate...", "  title=[Threshold Stack] open image1=[Threshold Stack] image2=[Threshold " + radius + "] image3=[-- None --]");
			run("Concatenate...", "  title=[Image Stack] open image1=[Image Stack] image2=[Image " + radius + "] image3=[-- None --]");
		}
		else{
			selectWindow("Threshold " + radius);
			rename("Threshold Stack");
			selectWindow("Image " + radius);
			rename("Image Stack");
		}
	}
		
	//Show threshold results to user
	close("Threshold");
	selectWindow("Threshold Stack");
	run("Subtract...", "value=128 stack");
	run("Merge Channels...", "c2=[Image Stack] c6=[Threshold Stack] create ignore keep");
	selectWindow("Merged");
	setBatchMode("show");
	waitForUser("Select the optimal threshold radius");

	//Retrieve the local threshold value
	selectWindow("Merged");
	Stack.getPosition(dummy, dummy, frame);
	close("Merged");
	selectWindow("Threshold Stack");
	setSlice(frame);
	meta = getMetadata("Label");
	run("Duplicate...", "title=[Local Test Mask]");
	close("Threshold Stack");
	local_threshold_radius = parseFloat(meta);
	
	return local_threshold_radius;
}

function medianRadius(i){
	//Get the iamge of the local selection from the image stack
	selectWindow("Image Stack");
	run("Duplicate...", "title=Image");
	close("Image Stack");
	selectWindow(i);
	run("Select None");

	//Run a series of local thresholds to allow the user to find the optimal threshold
	selectWindow(i);
	run("Duplicate...", "title=[Threshold]");
	selectWindow("Threshold");
	for(radius = min_median_radius; radius <= max_median_radius; radius+=median_step){
		showStatus("!Testing median radius: " + radius);
		selectWindow("Threshold");
		run("Duplicate...", "title=[Threshold " + radius + "]");
		selectWindow("Image");
		run("Duplicate...", "title=[Image " + radius + "]");
		selectWindow("Threshold " + radius);
		setMetadata("Label", radius);
		run("Median...", "radius=" + radius);
		if(isOpen("Threshold Stack")){
			run("Concatenate...", "  title=[Threshold Stack] open image1=[Threshold Stack] image2=[Threshold " + radius + "] image3=[-- None --]");
			run("Concatenate...", "  title=[Image Stack] open image1=[Image Stack] image2=[Image " + radius + "] image3=[-- None --]");
		}
		else{
			selectWindow("Threshold " + radius);
			rename("Threshold Stack");
			selectWindow("Image " + radius);
			rename("Image Stack");
		}
	}
		
	//Show threshold results to user
	close("Threshold");
	selectWindow("Threshold Stack");
	run("Merge Channels...", "c2=[Image Stack] c6=[Threshold Stack] create ignore keep");
	close("Image Stack");
	selectWindow("Merged");
	setBatchMode("show");
	waitForUser("Select the optimal median radius");

	//Retrieve the local threshold value
	selectWindow("Merged");
	Stack.getPosition(dummy, dummy, frame);
	close("Merged");
	selectWindow("Threshold Stack");
	setSlice(frame);
	meta = getMetadata("Label");
	run("Duplicate...", "title=[Local Median Mask]");
	close("Threshold Stack");
	median_radius = parseFloat(meta);
	close(i);

	return median_radius;
}



function filterStack(filter_values){
	//Apply the mask to the selected image region
	selectWindow("Image");
	run("Duplicate...", "title=[Test Image]");
	selectWindow("Local Median Mask");
	setThreshold(1, 255);
	run("Convert to Mask");
	run("Create Selection");
	selectWindow("Test Image");
	run("Restore Selection");
	setBackgroundColor(0, 0, 0);
	run("Clear Outside");
	run("Select None");
	
	//Analyze segmented mask
	selectWindow("Test Image");
	setThreshold(1, 255);
	run("Analyze Particles...", "  show=[Count Masks] display clear");
	
	selectWindow("Count Masks of Test Image");
	for(a=0; a<filter_label.length; a++){
		if(!matches(filter_label[a], "Sobel")){
			showStatus("!Running " + filter_label[a] + " filter.");
			run("Duplicate...", "title=[" + filter_label[a] + "]");
			selectWindow(filter_label[a]);
			run("32-bit");
			for(row=0; row<nResults; row++){
				obj_value = getResult(filter_label[a], row);
				selectWindow("Count Masks of Test Image");
				setThreshold(row+1, row+1);
				run("Create Selection");
				if(selectionType > -1){
					selectWindow(filter_label[a]);
					run("Restore Selection");
					run("Set...", "value=" + obj_value);
					run("Select None");
				}
			}
			selectWindow("Image");
			run("Duplicate...", "title=Image1");
			selectWindow("Image1");
			run("32-bit");
			run("Merge Channels...", "c2=Image1 c6=" + filter_label[a] + " create ignore");
			selectWindow("Composite");
			rename(filter_label[a]);
			Stack.setChannel(2);
			setMinAndMax(0, 0.00000001);
		}
	}
	close("Count Masks of Test Image");
	
	//Run Sobel analysis
	close("Test Image");
	selectWindow("Image");
	run("Duplicate...", "title=[Test Image]");
	selectWindow("Local Median Mask");
	setThreshold(1, 255);
	run("Convert to Mask");
	run("Create Selection");
	selectWindow("Test Image");
	run("Find Edges");
	run("Restore Selection");
	setBackgroundColor(0, 0, 0);
	run("Clear Outside");
	run("Select None");
	
	//Analyze segmented mask
	selectWindow("Test Image");
	setThreshold(1, 255);
	run("Analyze Particles...", "  show=[Count Masks] display clear");
	
	selectWindow("Count Masks of Test Image");
	run("32-bit");		
	for(a=0; a<filter_label.length; a++){
		if(matches(filter_label[a], "Sobel")){
			showStatus("!Running " + filter_label[a] + " filter.");
			run("Duplicate...", "title=[" + filter_label[a] + "]");
			selectWindow(filter_label[a]);
			run("32-bit");
			for(row=0; row<nResults; row++){
				obj_value = getResult("Mean", row);
				selectWindow("Count Masks of Test Image");
				setThreshold(row+1, row+1);
				run("Create Selection");
				if(selectionType > -1){
					selectWindow(filter_label[a]);
					run("Restore Selection");
					run("Set...", "value=" + obj_value);
					run("Select None");
				}
			}
			selectWindow("Image");
			run("Duplicate...", "title=Image1");
			selectWindow("Image1");
			run("32-bit");
			run("Merge Channels...", "c2=Image1 c6=" + filter_label[a] + " create ignore");
			selectWindow("Composite");
			rename(filter_label[a]);
			Stack.setChannel(2);
			setMinAndMax(0, 0.00000001);
		}
	}
	close("Test Image");
	close("Count Masks of Test Image");
	close("Local Median Mask");

	for(a=0; a<filter_label.length; a++){
		selectWindow(filter_label[a]);
		setBatchMode("show");
		run("Brightness/Contrast...");
		waitForUser("Set the " + toLowerCase(filter_label[a]) + " filter cutoff using the B&C tool and press okay.");
		getMinAndMax(min, max);
		filter_values[a] = min;
		if(isOpen("B&C")){
			selectWindow("B&C");
			run("Close");
		}
		close(filter_label[a]);
	}
	close("Image");
	return filter_values;
}

function processImage(i, local_threshold_radius, median_radius, filter_values){
	selectWindow(i);
	run("Select None");
	close("\\Others");
	run("Duplicate...", "title=[Mask]");
	selectWindow("Mask");
	resetMinAndMax();
	run("8-bit");
	showStatus("!Applying local threshold to full image...");
	run("Auto Local Threshold", "method=Phansalkar radius=" + local_threshold_radius + " parameter_1=0 parameter_2=0 white");
	showStatus("!Applying median filter to full image...");
	run("Median...", "radius=" + median_radius);
	showStatus("!Applying particle analysis filters to full image...");
	
	//Apply the mask to the selected image region
	selectWindow(i);
	run("Duplicate...", "title=[Test Image]");
	selectWindow("Mask");
	setThreshold(1, 255);
	run("Convert to Mask");
	run("Create Selection");
	selectWindow("Test Image");
	run("8-bit");
	run("Restore Selection");
	setBackgroundColor(0, 0, 0);
	run("Clear Outside");
	run("Select None");
	
	//Analyze segmented mask
	selectWindow("Test Image");
	setThreshold(1, 255);
	
	//Apply area and circularity filters in the particle analyzer tool for faster analysis
	min_area = 0;
	min_circularity = 0;
	for(a=0; a<filter_label.length; a++) if(matches(filter_label[a], "Area")) min_area = filter_values[a];
	for(a=0; a<filter_label.length; a++) if(matches(filter_label[a], "Circ.")) min_circularity = filter_values[a];
	
	run("Analyze Particles...", "size=" + min_area + "-Infinity circularity=" + min_circularity + "-1.00 show=[Count Masks] display clear");
	selectWindow("Count Masks of Test Image");
	print("" + nResults + " objects found.");
	for(row=0; row<nResults; row++){
		remove_object = false;
		for(a=0; a<filter_values.length; a++){
			if(!matches(filter_label[a], "Sobel")){
				obj_value = getResult(filter_label[a], row);
				if(obj_value < filter_values[a]) remove_object = true;
			}
		}
		if(remove_object){
			print("Removed object: " + row+1);
			setThreshold(row+1, row+1);
			run("Create Selection");
			if(selectionType > -1){
				run("Clear", "slice");
				run("Select None");
			}
		}
	}
	close("Test Image");
	close("Mask");
}
