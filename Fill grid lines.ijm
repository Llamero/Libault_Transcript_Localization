i = getTitle();
close("\\Others");
setBatchMode(true);
run("Hide Overlay"); //Remove overlay for faster processing
getDimensions(width, height, channels, slices, frames);
fillVerticalGridLines(i);
fillHorizontalGridLines(i);
setBatchMode("exit and display");

function fillVerticalGridLines(i){
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
		if(p == 0){ //Find start of 0 column
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
			makeRectangle(x_start-1, 0, 1, height);
			run("Copy");
			run("Internal Clipboard");
			selectWindow("Clipboard");
			rename("1");
			selectWindow(i);
			makeRectangle(x_end+1, 0, 1, height);
			run("Copy");
			run("Internal Clipboard");
			selectWindow("Clipboard");
			rename("2");
			run("Combine...", "stack1=1 stack2=2");
			selectWindow("Combined Stacks");
			run("Size...", "width=" + x_end-x_start+3 + " height=" + height + " depth=1 interpolation=Bilinear");
			selectWindow("Combined Stacks");
			run("Select All");
			run("Copy");
			selectWindow(i);
			makeRectangle(x_start-1, 0, x_end-x_start+3, height);
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

function fillHorizontalGridLines(i){
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
		if(p == 0){ //Find start of 0 row
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
			makeRectangle(0, y_start-1, width, 1);
			run("Copy");
			run("Internal Clipboard");
			selectWindow("Clipboard");
			rename("1");
			selectWindow(i);
			makeRectangle(0, y_end+1, width, 1);
			run("Copy");
			run("Internal Clipboard");
			selectWindow("Clipboard");
			rename("2");
			run("Combine...", "stack1=1 stack2=2 combine");
			selectWindow("Combined Stacks");
			run("Size...", "width=" + width + " height=" + y_end-y_start+3 + " depth=1 interpolation=Bilinear");
			selectWindow("Combined Stacks");
			run("Select All");
			run("Copy");
			selectWindow(i);
			makeRectangle(0, y_start-1, width, y_end-y_start+3);
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


