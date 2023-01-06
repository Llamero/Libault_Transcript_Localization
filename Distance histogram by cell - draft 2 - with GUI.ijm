max_distance = 1000;
cell_maps = newArray("Cell ID #", "Cell Area (px)", "Nucleus Area (px)", "Total transcript #", "Cytoplasm only transcript #", "Transcript density (RNA/px)", "Fraction of transcripts in nucleus", "Nucleus fractional area", "Median distance from nucleus incl. nucleus (px)", "Median distance from nucleus excl. nucleus (px)", "1st quartile distance w/ nucleus (px)", "1st quartile distance w/o nucleus (px)", "3rd quartile distance w/ nucleus (px)", "3rd quartile distance w/o nucleus (px)");
default_maps = newArray(true, true, true, true, true, true, true, true, true, true, true, true, true, true);
downsample_maps = 5; //Downsample maps to make the mapping run faster and reduce file size
starting_row = 2; //Row of the results table to start on.  Helps to exclude background object
setBatchMode(true);
test = true;
results_path = File.openDialog("Select path to segmentation results table.");
retry_limit = 3; //Number of times to rery making dam image

//Show GUI to have user choose filter settings
Dialog.create("Select maps to generate");
Dialog.addNumber("Maximum distance from nucleus (px)", max_distance);
Dialog.addNumber("Downsample maps", downsample_maps);
Dialog.addNumber("Starting row", starting_row);
Dialog.addMessage("\n");
Dialog.addCheckboxGroup(cell_maps.length, 1, cell_maps, default_maps);
Dialog.show();

max_distance = Dialog.getNumber();
downsample_maps = Dialog.getNumber();
starting_row = Dialog.getNumber();
map_count = 0;
for(a=0; a<cell_maps.length; a++){ //Count number of filters
	default_maps[a] = Dialog.getCheckbox();
	if(default_maps[a]) map_count++;	
}

if(isOpen("Results")){
	selectWindow("Results");
	run("Close");
}
open(results_path);
if(!isOpen("Results")){
	results_name = File.getName(results_path);
	Table.rename(results_name, "Results");
}
n_results = nResults;

print("\\Clear");
for(results_row = 0; results_row<n_results; results_row++){
	if(isOpen("Results")){
		selectWindow("Results");
		run("Close");
	}
	open(results_path);
	if(!isOpen("Results")){
		results_name = File.getName(results_path);
		Table.rename(results_name, "Results");
	}
	close("*");
	path_array = analyzeCells(results_row);
	mapResults(results_row, path_array);
}
setBatchMode("exit and display");

function mapResults(results_row, path_array){
	open(path_array[0] + path_array[1] + path_array[2]);
	selectWindow(path_array[1] + path_array[2]);
	Table.rename(path_array[1] + path_array[2], "Results");
	
	selectWindow("IDs");
	run("Bin...", "x=" + downsample_maps + " y=" + downsample_maps + " z=1 bin=Min");
	run("32-bit");
	setMetadata("Label", cell_maps[0]);
	for(col=0; col<cell_maps.length; col++){
		if(default_maps[col]){
			selectWindow("IDs");
			run("Duplicate...", "title=id");
			setMetadata("Label", cell_maps[col]);
			if(isOpen("Cell Map")){
				run("Concatenate...", "  title=[Cell Map] open image1=[Cell Map] image2=id image3=[-- None --]");
			}
			else{
				selectWindow("id");
				rename("Cell Map");
			}
		}
	}
	close("IDs");
	if(!default_maps[0] && nSlices == 1){ //If no map is selected
		close("*");
		return;
	}
	printUpdate("Starting to generate maps...");
	selectWindow("Cell Map");
	max_id = getResult(cell_maps[0], nResults-1);
	getHistogram(dummy, id_area_array, max_id+1, 0, max_id+1); //Get area of every ID

	for(row=0; row<nResults; row++){
		id = getResult(cell_maps[0], row);
		showStatus("!Mapping ID " + row + " of " + nResults);
		run("Select None");
		if(id_area_array[id] > 0 && id > 0){ //If the ID had area after binning
			bx = getResult("Bouding box X", row); //Get bounding box
			by = getResult("Bouding box Y", row);
			b_width = getResult("Bouding box width", row);
			b_height = getResult("Bouding box height", row);
			bx = round(bx/downsample_maps)-1; //Scale bounding box by downsample
			by = round(by/downsample_maps)-1;
			b_width = round(b_width/downsample_maps)+2;
			b_height = round(b_height/downsample_maps)+2;
			slice = 1;
			for(col=1; col<cell_maps.length; col++){
				if(default_maps[col]){
					slice++;
					if(row < starting_row) value = 0; //Clear IDs less than the starting row
					else value = getResult(cell_maps[col], row);
					setSlice(slice);
					makeRectangle(bx, by, b_width, b_height);
					run("Macro...", "code=[if(v==" + id + ") v=" + value + "] slice");					
				}
			}
		}
	}
	
	//If ID map is not selected, remove ID map
	selectWindow("Cell Map"); 
	if(!default_maps[0]){
		setSlice(1);
		run("Delete Slice");
	}
	run("physics");
	getLut(reds, greens, blues);
	reds[0] = 0;
	greens[0] = 0;
	blues[0] = 0;
	setLut(reds, greens, blues);
	saveAs("Tiff", path_array[0]+path_array[1]+" - cell maps.tif");
	
}

function analyzeCells(results_row){
	if(isOpen("Results")){
		selectWindow("Results");
		run("Close");
	}
	open(results_path);
	image_path = getResultString("Calcofluor path", results_row);
	print(image_path);
	nuc_path = getResultString("Nucleus mask path", results_row);
	trans_path = getResultString("Transcript list path", results_row);
	image_blur = getResult("Image blur", results_row);
	segmentation_threshold = getResult("Segmentation Threshold", results_row);

	print("--------------------------------------------------------");
	print("Processing file " + results_row+1 + " of " + nResults);
	
	//Watershed image
	close("*");
	if(!test){
		open(image_path);
		rename("image");
		run("Gaussian Blur...", "sigma=" + image_blur);
		setBatchMode("show");
		run("Morphological Segmentation");
		while(!isOpen("Morphological Segmentation"));
		wait(1000);
		call("inra.ijpb.plugins.MorphologicalSegmentation.setInputImageType", "border");
		call("inra.ijpb.plugins.MorphologicalSegmentation.setDisplayFormat", "Watershed lines");
		printUpdate("Starting watershed...");
		call("inra.ijpb.plugins.MorphologicalSegmentation.segment", "tolerance=" + segmentation_threshold, "calculateDams=true", "connectivity=4");
		print(1);
		while(true){ //Wait for segmentation to complete
			status = getInfo("log");
			if(indexOf(status, "Whole plugin took") > 0) break;
		}
		wait(10000); //If code hangs - increase delay-----------------------
		call("inra.ijpb.plugins.MorphologicalSegmentation.createResultImage");
		retry = 0;
		while(!isOpen("image-watershed-lines") && retry <= retry_limit){ //Try several times to render the dam image, incase the watershed GUI is slow to render the preview
			for(try=0; try<600; try++){
				wait(500);
				if(isOpen("image-watershed-lines")) break;
			}
			retry++;
			if(retry <= retry_limit){
				printUpdate("Dams image failed to be generated, retry #" + retry + " of " + retry_limit + ".");
				call("inra.ijpb.plugins.MorphologicalSegmentation.createResultImage");
			}
			else{
				printUpdate("ERROR: Failed to generate a dam image, try increasing the wait before calling \"createResultImage\".");
				return();
			}
		}
		selectWindow("image-watershed-lines");
		rename("dams");
		selectWindow("Morphological Segmentation");
		run("Close");
		printUpdate("Watershed complete.");
	}
	else{
		open("/media/Data-High_Speed/Ben/For Ben/watershed-lines.tif");
		selectWindow("watershed-lines.tif");
		rename("dams");
	}
	selectWindow("dams");
	
	//ID and analyze objects
	if(getInfo("os.name") == "Windows"){
		run("Dilate", "stack");
		run("Invert");
	}
	else run("Erode", "stack");
	printUpdate("Perfoming particle analysis...");
	run("Set Measurements...", "area centroid bounding redirect=None decimal=3");
	run("Analyze Particles...", "  show=[Count Masks] display clear");
	close("dams");
	
	//Get cell area and position
	selectWindow("Count Masks of dams");
	rename("IDs");
	getStatistics(dummy, dummy, dummy, n_id);
	if(nResults != n_id) print("Note: Basin had " + n_id + " objects while particle analyzer found " + nResults + " objects.");
	cell_area = newArray(nResults+1);
	cell_x = newArray(nResults+1);
	cell_y = newArray(nResults+1);
	cell_bx = newArray(nResults+1);
	cell_by = newArray(nResults+1);
	cell_width = newArray(nResults+1);
	cell_height = newArray(nResults+1);
	for(row=0; row<nResults; row++){
		cell_area[row+1] = getResult("Area", row);
		cell_x[row+1] = getResult("X", row);
		cell_y[row+1] = getResult("Y", row);
		cell_bx[row+1] = getResult("BX", row);
		cell_by[row+1] = getResult("BY", row);
		cell_width[row+1] = getResult("Width", row);
		cell_height[row+1] = getResult("Height", row);
	}

	//Remove nucleus area from mask
	open(nuc_path);
	selectWindow(File.getName(nuc_path));
	rename("nucleus mask");
	run("Subtract...", "value=254");
	imageCalculator("Multiply create 32-bit", "nucleus mask","IDs");
	selectWindow("Result of nucleus mask");
	getHistogram(values, nucleus_area, n_id+1, 0, n_id+1);
	close("Result of Nuclei mask.tif");
	selectWindow("Results");
	run("Close");
	run("Results... ", "open=[" + trans_path + "]");
	
	//Get EDT of distances from nuclei
	printUpdate("Perfoming Euclidean distance transform...");
	if(!test){
		selectWindow("nucleus mask");
		run("Duplicate...", "title=a");
		selectWindow("a");
		run("Multiply...", "value=255");
		run("Invert");
		run("Exact Euclidean Distance Transform (3D)");
		close("a");
	}
	else{
		open("/media/Data-High_Speed/Ben/For Ben/EDT.tif");
		rename("EDT");
	}
	
	//Get distance of each nucleus from transcipt
	selectWindow("EDT");
	for(row=0; row<nResults; row++){
		x=getResult("X", row);
		y=getResult("Y", row);
		d = getPixel(x, y);
		setResult("EDT", row, d);
	}

	selectWindow("IDs");
	for(row=0; row<nResults; row++){
		x=getResult("X", row);
		y=getResult("Y", row);
		id = getPixel(x, y);
		setResult("ID", row, id);
	}

	newImage("Hist", "32-bit black", n_id+1, max_distance+1, 1);
	selectWindow("Hist");
	for(row=0; row<nResults; row++){
		id=getResult("ID", row);
		d=getResult("EDT", row);
		d=round(d);
		if(d>max_distance) d=max_distance;
		v = getPixel(id, d);
		v++;
		setPixel(id, d, v);
	}

	//Get median distance form nucleus
	selectWindow("Hist");
	run("Duplicate...", "title=[Sum with nuc]");
	selectWindow("Sum with nuc");
	run("Bin...", "x=1 y=" + max_distance+1 + " bin=Sum");
	
	selectWindow("Hist");
	makeRectangle(0, 1, n_id+1, max_distance);
	run("Duplicate...", "title=[Sum wo nuc]");
	selectWindow("Sum wo nuc");
	run("Bin...", "x=1 y=" + max_distance + " bin=Sum");
	
	imageCalculator("Divide create 32-bit", "Sum wo nuc","Sum with nuc");
	selectWindow("Result of Sum wo nuc");
	rename("Cytoplasm ratio");

	sum_w_nuc = newArray(n_id+1);
	sum_wo_nuc = newArray(n_id+1);
	nuc_ratio = newArray(n_id+1);
	
	for(i=0; i<3; i++){ //Get total transcript counts for each cell ID
		if(i==0) selectWindow("Sum with nuc");
		else if(i==1) selectWindow("Sum wo nuc");
		else if(i==2) selectWindow("Cytoplasm ratio");
		for(id=0; id<=n_id; id++){
			v=getPixel(id, 0);
			if(i==0) sum_w_nuc[id] = v;
			else if(i==1) sum_wo_nuc[id] = v;
			else if(i==2) nuc_ratio[id] = 1-v;
		}
	}

	close("Sum with nuc");
	close("Sum wo nuc");
	close("Cytoplasm ratio");

	selectWindow("Hist");
	quartile_count_array = newArray(6);
	quartile_array = newArray(quartile_count_array.length);
	Table.create("Transcript localization");
	selectWindow("Transcript localization");

	for(id=0; id<=n_id; id++){
		quartile_count_array[0] = round(0.25*sum_w_nuc[id]);
		quartile_count_array[1] = round(0.5*sum_w_nuc[id]);
		quartile_count_array[2] = round(0.75*sum_w_nuc[id]);
		quartile_count_array[3] = round(0.25*sum_wo_nuc[id]);
		quartile_count_array[4] = round(0.5*sum_wo_nuc[id]);
		quartile_count_array[5] = round(0.75*sum_wo_nuc[id]);
		
		for(i=0; i<quartile_count_array.length; i++) quartile_array[i] = -1;
		
		w_nuc_count = 0;
		wo_nuc_count = 0;
		mid_index = quartile_count_array.length/2;
		for(d=0; d<=max_distance; d++){
			v=getPixel(id, d);
			w_nuc_count += v;
			if(d>0) wo_nuc_count += v;
			array_complete = true;
			for(i=0; i<quartile_count_array.length; i++){
				if(quartile_array[i] < 0){
					array_complete = false;
					if(i < mid_index){
						if(w_nuc_count >= quartile_count_array[i]) quartile_array[i] = d;
					}
					else{
						if(wo_nuc_count >= quartile_count_array[i]) quartile_array[i] = d;
					}
				}
			}
			if(array_complete) d=max_distance+1;	
		}

		Table.set("Cell ID #", id, id);
		Table.set("X location", id, cell_x[id]);
		Table.set("Y location", id, cell_y[id]);
		Table.set("Bouding box X", id, cell_bx[id]);
		Table.set("Bouding box Y", id, cell_by[id]);
		Table.set("Bouding box width", id, cell_width[id]);
		Table.set("Bouding box height", id, cell_height[id]);
		Table.set("Cell Area (px)", id, cell_area[id]);
		Table.set("Nucleus Area (px)", id, nucleus_area[id]);
		Table.set("Total transcript #", id, sum_w_nuc[id]);
		Table.set("Cytoplasm only transcript #", id, sum_wo_nuc[id]);
		Table.set("Transcript density (RNA/px)", id, sum_w_nuc[id]/cell_area[id]);
		Table.set("Fraction of transcripts in nucleus", id, nuc_ratio[id]);
		Table.set("Nucleus fractional area", id, nucleus_area[id]/cell_area[id]);
		Table.set("Median distance from nucleus incl. nucleus (px)", id, quartile_array[1]);
		Table.set("Median distance from nucleus excl. nucleus (px)", id, quartile_array[4]);
		Table.set("1st quartile distance w/ nucleus (px)", id, quartile_array[0]);
		Table.set("1st quartile distance w/o nucleus (px)", id, quartile_array[3]);
		Table.set("3rd quartile distance w/ nucleus (px)", id, quartile_array[2]);
		Table.set("3rd quartile distance w/o nucleus (px)", id, quartile_array[5]);
	}
	Table.update;
	out_dir = File.getDirectory(trans_path);
	prefix = File.getNameWithoutExtension(trans_path);
	selectWindow("Transcript localization");
	saveAs("Results", out_dir+prefix+" - localization results by cell.csv");
	run("Close");
	selectWindow("Results");
	saveAs("Results", out_dir+prefix+" - localization results by transcript.csv");
	run("Close");
	selectWindow("Hist");
	saveAs("Tiff", out_dir+prefix+" - transcript distance histogram by cell.csv");
	run("Close");
	selectWindow("IDs");
	close("\\Others");
	path_array = newArray(out_dir, prefix, " - localization results by cell.csv");
	return path_array;
}

function printUpdate(message){ //https://imagej.nih.gov/ij/macros/GetDateAndTime.txt
	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString ="Date: "+DayNames[dayOfWeek]+" ";
	if (dayOfMonth<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+"\nTime: ";
	if (hour<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+hour+":";
	if (minute<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+minute+":";
	if (second<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+second;
	print(TimeString +  " - " + message);
}
