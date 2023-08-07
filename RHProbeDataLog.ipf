#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "LabJackConstants" 


////////////////////// General Information about LabJack for Igor //////////////////////
//    Labjack has provided libraries for LabJack U3, U6, and U9 with XOPS and example procedures.
//    They are available for download here. Follow the readme within the zipped file to setup these 
//		libraries in Igor on your computer: 
//    https://labjack.com/support/software/examples/ud/igor-pro-windows-ud
//
//    It seems that these libraries are most compatible with Igor 8, so please upgrade your Igor. 
//    Use with Igor 8 32-bit only. This code does not work in Igor 8 64-bit
//    NOTE: If you get errors while starting Igor, try installing this driver too: 
//		https://labjack.com/support/software/installers/ud 
//    Download LabJack-2019-05-20.exe (or current version)

///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
/////////      ******RHProbeDataLog.ipf*******    /////////
/////////     Lauren Garofalo    23 May 2022            ///
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////

//  
//   ******RHProbeDataLog.ipf*******
//		This code runs a datalogging system for LabJack U6 for 3 analog channels on Igor 8 32-bit.
// 		The first two channels (Ch0 and Ch1) are Temperature and RH from a Vaisala HMP60 Probe. 
//		The third channel (Ch2) is the RH from a Omega HX71-V1 Probe. The code calling these 
//		variables in the "PingLabJack" function below. 

//		Wiring 	- 	Vaisala	Ch1 (Temp) 	to	LJ AIN0
// 						Vaisala	Ch2 (RH) 		to LJ AIN1
//						Vaisala	5V 				to LJ 5V
//						Vaisala	Ground 		to LJ GND
//
// 		Initiate the program with initLabjackPanel() in the command line. You can open the Panel
//		Windows>Panel Macros> Panel0
//
// 		The panel provides a place to enter offsets and slopes to convert from an analog Voltage
// 		signal to a meaningful value. These are specific to the set up of the probe and/or any
// 		calibrations. 
//
// 		This code updates the panel on a one second time basis and also writes the data to a
// 		comma delimited file of your chosen name (entered in a window dialog when the user presses 
//		the "Run" button). The timing is close to 1s, but there are some rounding errors, so if you need
//		a precise timestamp, you will have to improve the code. 
//
// 		Feel free to adjust based on your datalogging needs.
// 		Know that this will stop logging if the computer goes to sleep so adjust your 
// 		computer's sleep settings accordingly.


///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////

// If you add Channels, add additional global variables are their normal offeset and scale here.
// Then press "Initialize Panel" on the Panel. 
Function initLabjackPanel()
	String oldDF=GetDataFolder(1)
	SetDataFolder root:
	NewDataFolder/O/S Packages
	NewDataFolder/O/S LabJackU6
	String/G sIDMenu="_none_"
	Variable/G refNum=0
	Variable/G outVolts0=1
	Variable/G outVolts1=1
	
	Variable/G outValue = -9999
	Variable/G outValue0 = -9999
	Variable/G outValue1 = -9999
	Variable/G outValue2 = -9999
	
	Variable/G offsetCh0 = -40  //Vaisala HMP60 probe Temperature output. Range: 0 to 1 V = -40 to +60 C 
	Variable/G scalesetCh0=100
	Variable/G realvalueCh0 = -9999	
	
	Variable/G offsetCh1 = 0  //Vaisala HMP60 probe RH output. Range: 0 to 1 V = 0 to 100 % 
	Variable/G scalesetCh1=100
	Variable/G realvalueCh1 = -9999
	
	Variable/G offsetCh2 = 0 //Omega HX71-V1 RH output. Range: 0 to 5 V = 0 to 100 %
	Variable/G scalesetCh2= 20
	Variable/G realvalueCh2 = -9999		

	String/G fpath
	
	
End	


// Button controls - These link buttons on the panel to the functions that they will run

Function runButtonProc(ba) : ButtonControl  // "Run" button starts datalogging with saving
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			StartDataLog()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function stopButtonProc(ba) : ButtonControl  // "Stop" button stops datalogging and saving
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			StopDataLog()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function initButtonProc(ba) : ButtonControl  // "Initialize Panel" button creates global variables 
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			initLabjackPanel()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function LabJackErrorHandler(error)
	Variable error
	
	// Error code 0 is no error.
	if ( error != 0 )
		String errorStr=LJ_ErrorToString(error)
		printf "LabJack error detected: " + errorStr + "\r"
		printf "Done\r"
		abort "LabJack error detected: " + errorStr
	endif
End


//////////////
// This function is the heart of the code.
// First, it finds the labjack and prints information about it in the command line
// Second, it opens a dialog to ask for the filename to save to and adds the variable header
// Third, it runs in the background to get data from Labjack on 1 second time-base and save 
// the data to the file. 


Function StartDataLog()
	
	Variable error=0
	String address=""
	Variable handle=0
	Variable value=0.0
	Variable i=0
			 
	Printf "Driver Version=%.2f\r", LJ_DriverVersion()
	
	// Open first found LabJack U6
	error = LJ_OpenLabJack(LJ_dtU6, LJ_ctUSB, address, 1, handle)
	LabJackErrorHandler(error)

	// Read and display the serial number
	error = LJ_eGet(handle, LJ_ioGET_CONFIG, LJ_chSERIAL_NUMBER, 0, value)
	LabJackErrorHandler(error)
	Printf "Opened U6 with serial number %d\r", value

	// Read and display the hardware version of this U6.
	error = LJ_eGet(handle, LJ_ioGET_CONFIG, LJ_chHARDWARE_VERSION, 0, value)
	LabJackErrorHandler(error)
	Printf "Hardware version = %.2f\r", value
	
	// Read and display the firmware version of this U6.
	error = LJ_eGet(handle, LJ_ioGET_CONFIG, LJ_chFIRMWARE_VERSION, 0, value)
	LabJackErrorHandler(error)
	Printf "Firmware version = %.2f\r", value
		
	//Create a File - Open Dialog to ask for filename and adds header
	String/G fpath = CreateAFile()
	
//Execute the list of requests. Actually tells it to do all the things above. 
	error = LJ_GoOne(handle);
	LabJackErrorHandler(error)

	// In the background of IGOR, IGOR will ping the LabJack every second (60 ticks) to get the voltages and update panel.
	Variable numTicks = 60 // Run every 1 second (1 second = 60 ticks)
	CtrlNamedBackground LabJack, period=numTicks, proc = PingLabJack
	CtrlNamedBackground LabJack, start
	

End


/// CreateAFile() Opens a new file with the name provided by the user

Function/S CreateAFile()
    Variable refnum
    Open refnum
    if (refnum)   // This is your header. Add your variables here. Good practice is recording analog signal in your raw files in case you want to change the scaling factor later. 
        fprintf refnum, "IgorTime, Date, Time, Ch0Volts, Vaisala_Temp, Ch1Volts, Vaisala_RH, Ch2Volts, Omega_RH\r"
    endif
    FStatus refnum
    String filepath = S_path+S_fileName
    Close refnum
    return filepath
end

// AddtoFile(filepath, thingtoprint) adds a line (thingtoprint) to the file (filepath) 
Function AddToFile(String filepath, String thingtoprint)
    Variable refnum
    Open/A refnum as filepath
    if (refnum)
        fprintf refnum, thingtoprint
    endif
    Close refnum
end

// PingLabJack(s) reads analog values from the labjack 

Function PingLabJack(s)
	STRUCT WMBackgroundStruct &s
	
	//File information from above
	SVAR fpath = root:Packages:LabJackU6:fpath
	NVAR refNum=root:Packages:LabJackU6:refNum
	
	Variable outValue

	//Global variables so that they can be displayed on the Panel in real time
	NVAR outvalue0 = root:Packages:LabJackU6:outValue0
	NVAR outvalue1= root:Packages:LabJackU6:outValue1
	NVAR outvalue2= root:Packages:LabJackU6:outValue2
	
	NVAR offsetCh0=root:Packages:LabJackU6:offsetCh0
	NVAR offsetCh1=root:Packages:LabJackU6:offsetCh1
	NVAR offsetCh2=root:Packages:LabJackU6:offsetCh2
	
	NVAR scalesetCh0=root:Packages:LabJackU6:scalesetCh0
	NVAR scalesetCh1=root:Packages:LabJackU6:scalesetCh1
	NVAR scalesetCh2=root:Packages:LabJackU6:scalesetCh2
	
	NVAR realvalueCh0=root:Packages:LabJackU6:realvalueCh0
	NVAR realvalueCh1=root:Packages:LabJackU6:realvalueCh1
	NVAR realvalueCh2=root:Packages:LabJackU6:realvalueCh2
	
	//Pull Channel0 data - second argument is channel number
	Variable err=LJ_eAIN(refNum, 0, 0, LJ_rgBIP10V, 0, 1, 0, outValue)
	outvalue0 = outValue
	
	//Pull Channel1 data
	err=LJ_eAIN(refNum, 1, 0, LJ_rgBIP10V, 0, 1, 0, outValue)			
	outvalue1 = outValue
	
	//Pull Channel2 data
	err=LJ_eAIN(refNum, 2, 0, LJ_rgUNI5V, 0, 1, 0, outValue)			
	outvalue2 = outValue
	
	//Takes voltages and turns them into degree C and % humidity
	realvalueCh0 = outvalue0 * scalesetCh0 + offsetCh0
	realvalueCh1 = outvalue1 * scalesetCh1 + offsetCh1
	realvalueCh2 = outvalue2 * scalesetCh2 + offsetCh2
	variable mydatetime = datetime
	
	//Makes the string to print in the datafile. Includes IGOR time, String Date, String Time, Voltage and Converted Values

	String stringtoprint = num2istr(mydatetime) + "," + secs2date(mydatetime,-2) + "," + secs2time(mydatetime, 3) + "," + num2str(outvalue0)+ "," + num2str(realvalueCh0) + "," + num2str(outvalue1) + "," + num2str(realvalueCh1)+ "," + num2str(outvalue2) + "," + num2str(realvalueCh2) +"\r"
		
	//Adds that string to the file
   	AddToFile(fpath, stringtoprint)
   	
   	//Updates the panel so you can see current values
	ControlUpdate/A/W=Panel0

	// background functions need to return 0 to continuously run
	return 0
End


Function StopDataLog()
	CtrlNamedBackground LabJack, stop
End


//Panel macro

Window RH_LabJack() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(689,78,1272,450) as "RH and Temp LabJack Panel"
	ShowTools/A
	ShowInfo/W=$WinName(0,64)
	SetDrawLayer UserBack
	SetDrawEnv fillfgc= (52428,52428,52428)
	DrawRect 18,176,120,195
	SetDrawEnv fillfgc= (52428,52428,52428)
	DrawRect 17,294,119,313
	SetDrawEnv fsize= 14
	DrawText 152,125,"Click the Run button to start."
	DrawText 29,193,"Vaisala HMP60"
	DrawText 20,309,"Omega HX71-V1"
	SetDrawEnv fsize= 10
	DrawText 292,76,"If the computer falls asleep, data acquisition will stop.\rPlease adjust sleep timer settings accordingly.\r\rData acquisition will also stop while you edit a procedure.\rPlease compile after editing. "
	Button run,pos={32.00,86.00},size={105.00,64.00},proc=runButtonProc,title="Run"
	Button run,fSize=16,fStyle=1
	Button stop,pos={427.00,87.00},size={105.00,64.00},proc=stopButtonProc,title="Stop"
	Button stop,fSize=16,fStyle=1
	Button run1,pos={33.00,14.00},size={102.00,26.00},proc=initButtonProc,title="Initialize Panel"
	Button run1,fSize=12,fStyle=1
	ValDisplay valdisp0,pos={21.00,218.00},size={120.00,18.00},title="Ch0 V "
	ValDisplay valdisp0,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp0,value= #"root:Packages:LabJackU6:outValue0"
	ValDisplay valdisp1,pos={21.00,259.00},size={125.00,18.00},title="Ch1 V "
	ValDisplay valdisp1,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp1,value= #"root:Packages:LabJackU6:outValue1"
	SetVariable offset0,pos={162.00,218.00},size={100.00,19.00},title="Ch0 Offset "
	SetVariable offset0,limits={-inf,inf,0},value= root:Packages:LabJackU6:offsetCh0
	SetVariable offset1,pos={162.00,259.00},size={100.00,19.00},title="Ch1 Offset "
	SetVariable offset1,limits={-inf,inf,0},value= root:Packages:LabJackU6:offsetCh1
	SetVariable scale0,pos={277.00,217.00},size={100.00,19.00},title="Ch0 Scale "
	SetVariable scale0,limits={-inf,inf,0},value= root:Packages:LabJackU6:scalesetCh0
	SetVariable scaleset1,pos={277.00,258.00},size={100.00,19.00},title="Ch1 Scale "
	SetVariable scaleset1,limits={-inf,inf,0},value= root:Packages:LabJackU6:scalesetCh1
	ValDisplay valdisp2,pos={412.00,257.00},size={125.00,18.00},title="Vaisala_RH "
	ValDisplay valdisp2,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp2,value= #"root:Packages:LabJackU6:realvalueCh1"
	ValDisplay valdisp3,pos={405.00,216.00},size={125.00,18.00},title="Vaisala_Temp "
	ValDisplay valdisp3,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp3,value= #"root:Packages:LabJackU6:realvalueCh0"
	ValDisplay valdisp8,pos={13.00,325.00},size={125.00,18.00},title="Ch2 V "
	ValDisplay valdisp8,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp8,value= #"root:Packages:LabJackU6:outValue2"
	SetVariable offset4,pos={161.00,325.00},size={100.00,19.00},title="Ch2 Offset "
	SetVariable offset4,limits={-inf,inf,0},value= root:Packages:LabJackU6:offsetCh2
	SetVariable scaleset4,pos={282.00,324.00},size={100.00,19.00},title="Ch2 Scale "
	SetVariable scaleset4,limits={-inf,inf,0},value= root:Packages:LabJackU6:scalesetCh2
	ValDisplay valdisp9,pos={412.00,325.00},size={125.00,18.00},title="Omega_RH"
	ValDisplay valdisp9,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp9,value= #"root:Packages:LabJackU6:realvalueCh2"
EndMacro