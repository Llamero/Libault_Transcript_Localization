max_distance = 1000;
setBatchMode(true);
selectWindow("basins.tif");
getStatistics(dummy, dummy, dummy, n_id);
run("Duplicate...", "title=[dams]");
selectWindow("dams");
setMinAndMax(0, 1);
run("8-bit");
run("Dilate");
run("Subtract...", "value=254");
imageCalculator("Multiply create 32-bit", "basins.tif","dams");
selectWindow("Result of basins.tif");
run("Set Measurements...", "area min centroid center redirect=None decimal=3");
setThreshold(0.5, 1e30);
run("Analyze Particles...", "  show=Nothing display clear");
close("Result of basins.tif");
close("dams");
if(nResults != n_id) print("Note: Basin had " + n_id + " objects while particle analyzer found " + nResults + " objects.");
cell_area = newArray(nResults+1);
cell_x = newArray(nResults+1);
cell_y = newArray(nResults+1);
for(row=0; row<nResults; row++){
	min = getResult("Min", row);
	max = getResult("Max", row);
	if(min != max) exit("Error: Object found with two IDs: " + min + " and " + max + ".");
	if(cell_area[min] > 0) print("Note: Object #" + min + " has already been found.");
	cell_area[min] = getResult("Area", row) + cell_area[min];
	cell_x[min] = getResult("X", row);
	cell_y[min] = getResult("Y", row);
}

selectWindow("Nuclei mask.tif");
imageCalculator("Multiply create 32-bit", "Nuclei mask.tif","basins.tif");
selectWindow("Result of Nuclei mask.tif");
getHistogram(values, nucleus_area, n_id+1, 0, n_id+1);
close("Result of Nuclei mask.tif");

selectWindow("Results");
run("Close");
run("Results... ", "open=[E:/ImageJ Macros/Libault lab/OneDrive_2022-09-19/For Ben/17G195900 Coordinates.txt]");

selectWindow("EDT.tif");
for(row=0; row<nResults; row++){
	x=getResult("X", row);
	y=getResult("Y", row);
	d = getPixel(x, y);
	setResult("EDT", row, d);
}

selectWindow("basins.tif");
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

for(i=0; i<3; i++){
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
	Table.set("ID", id, id);
	Table.set("X location", id, cell_x[id]);
	Table.set("Y location", id, cell_y[id]);
	Table.set("Cell Area", id, cell_area[id]);
	Table.set("Nucleus Area", id, nucleus_area[id]);
	Table.set("Total transcript #", id, sum_w_nuc[id]);
	Table.set("Cytplasm only transcript #", id, sum_wo_nuc[id]);
	Table.set("Transcript density (RNA/px)", id, sum_w_nuc[id]/cell_area[id]);
	Table.set("Ratio of transcripts in nucleus", id, nuc_ratio[id]);
	Table.set("Ratio nucleus area", id, nucleus_area[id]/cell_area[id]);
	Table.set("Median distance w/ nucleus (px)", id, quartile_array[1]);
	Table.set("Median distance w/o nucleus (px)", id, quartile_array[4]);
	Table.set("1st quartile distance w/ nucleus (px)", id, quartile_array[0]);
	Table.set("1st quartile distance w/o nucleus (px)", id, quartile_array[3]);
	Table.set("3rd quartile distance w/ nucleus (px)", id, quartile_array[2]);
	Table.set("3rd quartile distance w/o nucleus (px)", id, quartile_array[5]);
}
Table.update;
setBatchMode("exit and display");
