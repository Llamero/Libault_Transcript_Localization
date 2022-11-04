close("\\Others");
setBatchMode(true);
setBatchMode("hide");
local_threshold_area_fraction = 5; //Fractional width/height of total image to test for a local threshold to speed up the analysis
min_local_threshold_radius = 3; //Minimum local threshold radius to test
max_local_threshold_radius = 100; //Maximum local threshold radius to test
local_threshold_radius_step_factor = 1.4; //Factor to increment local threshold radius by
min_median_radius = 5; //Minimum local threshold radius to test
max_median_radius = 30; //Maximum local threshold radius to test
area_steps = 10; //Number of area steps to test
sobel_steps = 10; //Number of sobel (derivative) steps to test
mean_steps = 10; //Number of mean steps to test
stdev_steps = 10; //Number of stdev stpes to test
exp_filter_step = false; //Whether to step filter increments linearly or exponentially

i = getTitle();
local_threshold_radius = 0;
median_radius = 0;
area_filter = 0;
sobel_filter = 0;
//mean_filter = 0;
//stdev_filter = 0;

//findRoot(i);
while(local_threshold_radius < 1) local_threshold_radius = localThreshold(i);
while(median_radius < 1) median_radius = medianRadius("Local Test Mask");
while(area_filter < 1) area_filter = areaFilter();
while(sobel_filter < 1) sobel_filter = sobelFilter();
while(mean_filter < 1) mean_filter = meanFilter();
while(stdev_filter < 1) stdev_filter = stdevFilter();
//processImage(i, local_threshold_radius, median_radius, area_filter, mean_filter, stdev_filter);


setBatchMode("exit and display");
exit();


selectWindow(i);
showStatus("Applying local radius: " + local_threshold_radius);
run("Select None");
run("Duplicate...", "title=[Nucleus Mask]");
selectWindow("Nucleus Mask");
resetMinAndMax();
run("8-bit");
run("Auto Local Threshold", "method=Phansalkar radius=" + local_threshold_radius + " parameter_1=0 parameter_2=0 white");
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
	run("Set Measurements...", "area redirect=None decimal=3");
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
	for(radius = min_median_radius; radius <= max_median_radius; radius+=min_median_radius){
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

	return median_radius;
}

function areaFilter(){
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
	run("Set Measurements...", "area mean standard min center median redirect=None decimal=3");
	run("Analyze Particles...", "  show=[Masks] display clear");
	
	//Find min and max parameters
	min_area = getResult("Area", 0);
	max_area = min_area;
	for(row=0; row<nResults; row++){
		area = getResult("Area", row);
		if(area < min_area) min_area = area;
		else if(area > max_area) max_area = area;
	}
	
	//Create filter hyperstack
	d_area = max_area-min_area;
	if(exp_filter_step) area_factor = Math.pow(d_area, 1/area_steps);
	else area_factor = d_area/(area_steps-1);

	n_area=0;
	step = 0;
	area = min_area;
	while(area<=max_area){
		selectWindow("Image");
		run("Duplicate...", "title=[Image1]");
		selectWindow("Mask of Test Image");
		run("Analyze Particles...", "size=" + area + "-Infinity show=Masks clear");
		selectWindow("Mask of Mask of Test Image");
		setMetadata("Label", area);
		showProgress(step++, area_steps);
		showStatus("!" + step + " of " + area_steps);
		close("Mask of Test Image");
		selectWindow("Mask of Mask of Test Image");
		run("Duplicate...", "title=[Mask of Test Image]");

		if(isOpen("Threshold Stack")){
			run("Concatenate...", "  title=[Threshold Stack] open image1=[Threshold Stack] image2=[Mask of Mask of Test Image] image3=[-- None --]");
			run("Concatenate...", "  title=[Image Stack] open image1=[Image Stack] image2=[Image1] image3=[-- None --]");
		}
		else{
			selectWindow("Mask of Mask of Test Image");
			rename("Threshold Stack");
			selectWindow("Image1");
			rename("Image Stack");
		}

		if(exp_filter_step) area = min_area + Math.pow(area_factor, ++n_area);
		else area += area_factor;
		close("Mask of Mask of Test Image");	
	}
	close("Mask of Test Image");
	close("Test Image");
	close("Local Median Mask");
	close("Local Test Mask");
	
	//Show threshold results to user
	selectWindow("Threshold Stack");
	selectWindow("Threshold Stack");
	run("Duplicate...", "title=[Threshold Mask] duplicate");
	selectWindow("Threshold Mask");
	setMinAndMax(0, 1);
	run("8-bit");
	run("Subtract...", "value=128 stack");
	run("Merge Channels...", "c2=[Image Stack] c6=[Threshold Mask] create ignore");
	selectWindow("Merged");
	setBatchMode("show");
	waitForUser("Select the optimal area filter");

	//Retrieve the local threshold value
	selectWindow("Merged");
	Stack.getPosition(dummy, dummy, frame);
	close("Merged");
	selectWindow("Threshold Stack");
	setSlice(frame);
	meta = getMetadata("Label");
	run("Duplicate...", "title=[Local Median Mask]");
	close("Threshold Stack");
	area_filter = parseFloat(meta);

	return area_filter;	
}

function sobelFilter(){
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
	run("Set Measurements...", "area mean standard min center median redirect=None decimal=3");
	run("Analyze Particles...", "  show=[Count Masks] display clear");
	
	//Find min and max parameters
	min_mean = getResult("Mean", 0);
	max_mean = min_mean;
	for(row=0; row<nResults; row++){
		mean = getResult("Mean", row);
		if(mean < min_mean) min_mean = mean;
		else if(mean > max_mean) max_mean = mean;
	}
	
	//Create filter hyperstack
	d_mean = max_mean-min_mean;
	mean_factor = Math.pow(d_mean, 1/mean_steps);

	n_mean=0;
	step = 0;
	mean = min_mean;
	while(mean<=max_mean){
		selectWindow("Image");
		run("Duplicate...", "title=[Image1]");
		selectWindow("Count Masks of Test Image");
		run("Duplicate...", "title=[Filtered Mean Mask]");
		selectWindow("Filtered Mean Mask");
		setMetadata("Label", mean);
		for(row=0; row<nResults; row++){
			obj_mean = getResult("Mean", row);
			if(obj_mean<mean){
				setThreshold(row+1, row+1);
				run("Create Selection");
				if(selectionType > -1){
					run("Clear", "slice");
					run("Select None");
				}
			}
		}	
		showProgress(step++, mean_steps);
		showStatus("!" + step + " of " + mean_steps);
		
		close("Count Masks of Test Image");
		selectWindow("Filtered Mean Mask");
		run("Duplicate...", "title=[Count Masks of Test Image]");

		if(isOpen("Threshold Stack")){
			run("Concatenate...", "  title=[Threshold Stack] open image1=[Threshold Stack] image2=[Filtered Mean Mask] image3=[-- None --]");
			run("Concatenate...", "  title=[Image Stack] open image1=[Image Stack] image2=[Image1] image3=[-- None --]");
		}
		else{
			selectWindow("Filtered Mean Mask");
			rename("Threshold Stack");
			selectWindow("Image1");
			rename("Image Stack");
		}

		mean = min_mean + Math.pow(mean_factor, ++n_mean);
		close("Filtered Mean Mask");	
	}
	close("Count Masks of Test Image");
	close("Test Image");
	close("Local Median Mask");
	close("Local Test Mask");
	
	//Show threshold results to user
	selectWindow("Threshold Stack");
	selectWindow("Threshold Stack");
	run("Duplicate...", "title=[Threshold Mask] duplicate");
	selectWindow("Threshold Mask");
	setMinAndMax(0, 1);
	run("8-bit");
	run("Subtract...", "value=128 stack");
	run("Merge Channels...", "c2=[Image Stack] c6=[Threshold Mask] create ignore");
	selectWindow("Merged");
	setBatchMode("show");
	waitForUser("Select the optimal mean filter");

	//Retrieve the local threshold value
	selectWindow("Merged");
	Stack.getPosition(dummy, dummy, frame);
	close("Merged");
	selectWindow("Threshold Stack");
	setSlice(frame);
	meta = getMetadata("Label");
	run("Duplicate...", "title=[Local Median Mask]");
	close("Threshold Stack");
	mean_filter = parseFloat(meta);

	return mean_filter;	
}

function meanFilter(){
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
	run("Set Measurements...", "area mean standard min center median redirect=None decimal=3");
	run("Analyze Particles...", "  show=[Count Masks] display clear");
	
	//Find min and max parameters
	min_mean = getResult("Mean", 0);
	max_mean = min_mean;
	for(row=0; row<nResults; row++){
		mean = getResult("Mean", row);
		if(mean < min_mean) min_mean = mean;
		else if(mean > max_mean) max_mean = mean;
	}
	
	//Create filter hyperstack
	d_mean = max_mean-min_mean;
	mean_factor = Math.pow(d_mean, 1/mean_steps);

	n_mean=0;
	step = 0;
	mean = min_mean;
	while(mean<=max_mean){
		selectWindow("Image");
		run("Duplicate...", "title=[Image1]");
		selectWindow("Count Masks of Test Image");
		run("Duplicate...", "title=[Filtered Mean Mask]");
		selectWindow("Filtered Mean Mask");
		setMetadata("Label", mean);
		for(row=0; row<nResults; row++){
			obj_mean = getResult("Mean", row);
			if(obj_mean<mean){
				setThreshold(row+1, row+1);
				run("Create Selection");
				if(selectionType > -1){
					run("Clear", "slice");
					run("Select None");
				}
			}
		}	
		showProgress(step++, mean_steps);
		showStatus("!" + step + " of " + mean_steps);
		
		close("Count Masks of Test Image");
		selectWindow("Filtered Mean Mask");
		run("Duplicate...", "title=[Count Masks of Test Image]");

		if(isOpen("Threshold Stack")){
			run("Concatenate...", "  title=[Threshold Stack] open image1=[Threshold Stack] image2=[Filtered Mean Mask] image3=[-- None --]");
			run("Concatenate...", "  title=[Image Stack] open image1=[Image Stack] image2=[Image1] image3=[-- None --]");
		}
		else{
			selectWindow("Filtered Mean Mask");
			rename("Threshold Stack");
			selectWindow("Image1");
			rename("Image Stack");
		}

		mean = min_mean + Math.pow(mean_factor, ++n_mean);
		close("Filtered Mean Mask");	
	}
	close("Count Masks of Test Image");
	close("Test Image");
	close("Local Median Mask");
	close("Local Test Mask");
	
	//Show threshold results to user
	selectWindow("Threshold Stack");
	selectWindow("Threshold Stack");
	run("Duplicate...", "title=[Threshold Mask] duplicate");
	selectWindow("Threshold Mask");
	setMinAndMax(0, 1);
	run("8-bit");
	run("Subtract...", "value=128 stack");
	run("Merge Channels...", "c2=[Image Stack] c6=[Threshold Mask] create ignore");
	selectWindow("Merged");
	setBatchMode("show");
	waitForUser("Select the optimal mean filter");

	//Retrieve the local threshold value
	selectWindow("Merged");
	Stack.getPosition(dummy, dummy, frame);
	close("Merged");
	selectWindow("Threshold Stack");
	setSlice(frame);
	meta = getMetadata("Label");
	run("Duplicate...", "title=[Local Median Mask]");
	close("Threshold Stack");
	mean_filter = parseFloat(meta);

	return mean_filter;	
}

function stdevFilter(){
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
	run("Set Measurements...", "area mean standard min center median redirect=None decimal=3");
	run("Analyze Particles...", "  show=[Count Masks] display clear");
	
	//Find min and max parameters
	min_stdev = getResult("StdDev", 0);
	max_stdev = min_stdev;
	for(row=0; row<nResults; row++){
		stdev = getResult("StdDev", row);
		if(stdev < min_stdev) min_stdev = stdev;
		else if(stdev > max_stdev) max_stdev = stdev;
	}
	
	//Create filter hyperstack
	d_stdev = max_stdev-min_stdev;
	stdev_factor = Math.pow(d_stdev, 1/stdev_steps);

	n_stdev=0;
	step = 0;
	stdev = min_stdev;
	while(stdev<=max_stdev){
		selectWindow("Image");
		run("Duplicate...", "title=[Image1]");
		selectWindow("Count Masks of Test Image");
		run("Duplicate...", "title=[Filtered Stdev Mask]");
		selectWindow("Filtered Stdev Mask");
		setMetadata("Label", stdev);
		for(row=0; row<nResults; row++){
			obj_stdev = getResult("StdDev", row);
			if(obj_stdev<stdev){
				setThreshold(row+1, row+1);
				run("Create Selection");
				if(selectionType > -1){
					run("Clear", "slice");
					run("Select None");
				}
			}
		}	
		showProgress(step++, stdev_steps);
		showStatus("!" + step + " of " + stdev_steps);
		
		close("Count Masks of Test Image");
		selectWindow("Filtered Stdev Mask");
		run("Duplicate...", "title=[Count Masks of Test Image]");

		if(isOpen("Threshold Stack")){
			run("Concatenate...", "  title=[Threshold Stack] open image1=[Threshold Stack] image2=[Filtered Stdev Mask] image3=[-- None --]");
			run("Concatenate...", "  title=[Image Stack] open image1=[Image Stack] image2=[Image1] image3=[-- None --]");
		}
		else{
			selectWindow("Filtered Stdev Mask");
			rename("Threshold Stack");
			selectWindow("Image1");
			rename("Image Stack");
		}

		stdev = min_stdev + Math.pow(stdev_factor, ++n_stdev);
		close("Filtered Stdev Mask");	
	}
	close("Count Masks of Test Image");
	close("Test Image");
	close("Local Median Mask");
	close("Local Test Mask");
	
	//Show threshold results to user
	selectWindow("Threshold Stack");
	selectWindow("Threshold Stack");
	run("Duplicate...", "title=[Threshold Mask] duplicate");
	selectWindow("Threshold Mask");
	setMinAndMax(0, 1);
	run("8-bit");
	run("Subtract...", "value=128 stack");
	run("Merge Channels...", "c2=[Image Stack] c6=[Threshold Mask] create ignore");
	selectWindow("Merged");
	setBatchMode("show");
	waitForUser("Select the optimal stdev filter");

	//Retrieve the local threshold value
	selectWindow("Merged");
	Stack.getPosition(dummy, dummy, frame);
	close("Merged");
	selectWindow("Threshold Stack");
	setSlice(frame);
	meta = getMetadata("Label");
	run("Duplicate...", "title=[Local Median Mask]");
	close("Threshold Stack");
	stdev_filter = parseFloat(meta);

	return stdev_filter;	
}

function processImage(i, local_threshold_radius, median_radius, area_filter, mean_filter, stdev_filter){
	setBatchMode("exit and display");
	selectWindow(i);
	run("Select None");
	close("\\Others");
	run("Duplicate...", "title=[Mask]");
	selectWindow("Mask");
	resetMinAndMax();
	run("8-bit");
	showStatus("!Applying local threshold to full iamge...");
	run("Auto Local Threshold", "method=Phansalkar radius=" + local_threshold_radius + " parameter_1=0 parameter_2=0 white");
	showStatus("!Applying median filter to full iamge...");
	run("Median...", "radius=" + radius);
	showStatus("!Applying particle analysis filters to full iamge...");
	
	//Apply the mask to the selected image region
	selectWindow(i);
	run("Duplicate...", "title=[Test Image]");
	selectWindow("Mask");
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
	run("Set Measurements...", "area mean standard min center median redirect=None decimal=3");
	run("Analyze Particles...", "size=" + area_filter + "-Infinity  show=[Count Masks] display clear");
	filter_string = "code=[if(";
	for(row=0; row<nResults; row++){
		showProgress(row, nResults);
		obj_mean = getResult("Mean", row);
		obj_stdev = getResult("StdDev", row);
		if(obj_mean<mean_filter || obj_area<area_filter){
			filter_string += "v==" + row+1 + " || ";
			setThreshold(row+1, row+1);
			run("Create Selection");
			if(selectionType > -1){
				run("Clear", "slice");
				run("Select None");
			}
		}
	}
	filter_string += "false) v=0; ]";
//	run("Macro...", filter_string);	

	
	
}
