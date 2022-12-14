# Reference Software for Tiny Yolo v3 Quantization

* How to run?
To evaluate the original floating point model, run `tiny-yolo-aix2022.sh`.
To evaluate the quantized model, run `tiny-yolo-aix2022-int8.sh`.
You can also test the quantized model using `tiny-yolo-aix2022-int8-test.sh` and visualize the prediction result.

* Tips
To save the quantized model, use flag `-save_params` at the end of command (see `tiny-yolo-aix2022-int8.sh`)

//=========================================================================
// UNIX
//=========================================================================
After decompressing the zip file, you can use the following commands:
cd skeleton-v1.1		// Direct to the code folder
make			        // Compile the code
cd bin/dataset		    // Go to the bin/dataset/
python make_list_cur.py	// Update the directories for test images
cd ..				    // Go to bin/
sh tiny-yolo-aix2022.sh	// Do inference on all test images, and calculate mAP

//=========================================================================
//Windows
//=========================================================================
After decompressing the zip file, you can use the following commands:
Go to skeleton-v1.1
Open the VS solution (yolo_cpu.sln) and compile the code
cd bin/dataset		    // Go to the bin/dataset/
python make_list_cur.py	// Update the directories for test images
cd ..				    // Go to bin/
yolo_cpu.cmd		    // Do inference on all test images, and calculate mAP

Note: 
If there is a version conflict, remove yolo_cpu.sln, and double click to yolo_cpu.vcxproj to make a new project with your VS version
