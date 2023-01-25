min_cutoff = 0;
min_buffer = 1;
max_buffer = 5; //Padding (in pixels) added to the min width of a grid line to remove lines when tiles are not perfectly aligned
min_radius = 15;
max_radius = 50;
radius_step = 5;

i = getTitle();
run("Hide Overlay"); //Remove overlay for faster processing
close("\\Others");
run("Grays");
setBatchMode(true);
//setBatchMode("hide");
getDimensions(width, height, channels, slices, frames);
for(buffer=min_buffer; buffer <= max_buffer; buffer++){
	showProgress(buffer-min_buffer, max_buffer-min_buffer+1);
	selectWindow(i);
	run("Duplicate...", "title=[Buffer " + buffer + "]");
	fillVerticalGridLines("Buffer " + buffer, buffer);
	fillHorizontalGridLines("Buffer " + buffer, buffer);
	if(isOpen("Buffer Stack")){
		run("Concatenate...", "  title=[Buffer Stack] open image1=[Buffer Stack] image2=[Buffer " + buffer + "] image3=[-- None --]");
	}
	else{
		selectWindow("Buffer " + buffer);
		rename("Buffer Stack");
	}
}
selectWindow("Buffer Stack");
setBatchMode("show");
waitForUser("Select the minimum amount of padding needed");
setBatchMode("hide");
run("Duplicate...", "title=[No grid]");
selectWindow("No grid");
resetMinAndMax();
//run("8-bit");
for(radius = min_radius; radius <= max_radius; radius += radius_step){
	
}

//run("Auto Local Threshold", "method=Phansalkar radius=30 parameter_1=0 parameter_2=0 white");

close("Buffer Stack");
setBatchMode("exit and display");

function fillVerticalGridLines(i, buffer){
	//Generate sum column to find columns that are all 0
	selectWindow(i);
	run("Select None");
	run("Duplicate...", "title=[x]");
	selectWindow("x");
	run("32-bit");
	run("Bin...", "x=1 y=" + height + " bin=Sum");
	
	//Search for all 0 columns
	x_start = -1;
	x_end = -1;
	selectWindow("x");
	for(x=0; x<height; x++){
		p = getPixel(x, 0);
		if(p <= min_cutoff){ //Find start of 0 column
			if(x_start < 0){
				x_start = x;
			}
			else{
				x_end = x;
			}
		}
		else if(x_start > 0){ //If there is a starting 0 column, then the first non 0 column is the end of the stretch of 0s
			 //replace grid line with bilinear interpolation of preceding and following column
			selectWindow(i);
			makeRectangle(x_start-buffer, 0, 1, height);
			run("Copy");
			run("Internal Clipboard");
			selectWindow("Clipboard");
			rename("1");
			selectWindow(i);
			makeRectangle(x_end+buffer, 0, 1, height);
			run("Copy");
			run("Internal Clipboard");
			selectWindow("Clipboard");
			rename("2");
			run("Combine...", "stack1=1 stack2=2");
			selectWindow("Combined Stacks");
			run("Size...", "width=" + x_end-x_start+2*buffer+1 + " height=" + height + " depth=1 interpolation=Bilinear");
			selectWindow("Combined Stacks");
			run("Select All");
			run("Copy");
			selectWindow(i);
			makeRectangle(x_start-1, 0, x_end-x_start+2*buffer+1, height);
			run("Paste");
			run("Select None");
			close("Combined Stacks");
			
			//Reset start and end variables
			x_start = -1;
			x_end = -1;
			//Bring the Ysearch window back to the top
			selectWindow("x");
		}
	}
	close("x");
}

function fillHorizontalGridLines(i, buffer){
	//Generate sum column to find rows that are all 0
	selectWindow(i);
	run("Select None");
	run("Duplicate...", "title=[y]");
	selectWindow("y");
	run("32-bit");
	run("Bin...", "x=" + width + " y=1 bin=Sum");
	
	//Search for all 0 rows
	y_start = -1;
	y_end = -1;
	selectWindow("y");
	for(y=0; y<height; y++){
		p = getPixel(0,y);
		if(p <= min_cutoff){ //Find start of 0 row
			if(y_start < 0){
				y_start = y;
			}
			else{
				y_end = y;
			}
		}
		else if(y_start > 0){ //If there is a starting 0 row, then the first non 0 row is the end of the stretch of 0s
			 //replace grid line with bilinear interpolation of preceding and following row
			selectWindow(i);
			makeRectangle(0, y_start-buffer, width, 1);
			run("Copy");
			run("Internal Clipboard");
			selectWindow("Clipboard");
			rename("1");
			selectWindow(i);
			makeRectangle(0, y_end+buffer, width, 1);
			run("Copy");
			run("Internal Clipboard");
			selectWindow("Clipboard");
			rename("2");
			run("Combine...", "stack1=1 stack2=2 combine");
			selectWindow("Combined Stacks");
			run("Size...", "width=" + width + " height=" + y_end-y_start+2*buffer+1 + " depth=1 interpolation=Bilinear");
			selectWindow("Combined Stacks");
			run("Select All");
			run("Copy");
			selectWindow(i);
			makeRectangle(0, y_start-1, width, y_end-y_start+2*buffer+1);
			run("Paste");
			run("Select None");
			close("Combined Stacks");
			
			//Reset start and end variables
			y_start = -1;
			y_end = -1;
			
			//Bring the Ysearch window back to the top
			selectWindow("y");
		}
	}
	close("y");
}


