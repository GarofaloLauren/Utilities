#pragma rtGlobals=1		// Use modern global access method.
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


//================== MFC_Control.ipf =========================      
//============   Lauren Garofalo    23 March 2023  ===========   


// This code runs up to four mass flow controllers on two U6 LabJacks. It can set voltages, and
// read and log analog signals from MKS MFCs. While the code can send signals to up 
// to 2 LabJacks, it can only connect at one at a time. So reading/writing is limited to the active 
// labjack. 
//
// The input voltage for an MKS MFC is 0-5V which covers the stated range of the MFC.
// 
// To convert the measured flow signal output voltage to flow, the panel incorporates the 
// range of the MFC, as well as offset and slope from a calibration. The units of flow are 
// whatever the units of the range, offset, and slope. (Notes on calibration below)

// Start Live Updates updates the panel every second
// Start Writing opens a dialog to name a data file
// Stop Updates or Writing stops datalogging and panel updates process

// I've also included a scan feature which steps through MFC voltages from 0.5V to 4.5V in 
// 30 second intervals. The data from this scan can be used to make a calibration curve 
// Measured flow vs Gilibrator Flow (y vs x). Remember than mass flow controllers are mass
// flow while gilibrators are volumetric flow. 

// Wiring for One MKS 2159B-type MFC. Additional MFC follow similar wiring at AIN2, AIN3 and DAC1 positions
 
//  			- 	MFC Pin2 (Flow Signal Output)	to	LJ AIN1
//					MFC	 Pin8 (Set Point Input) 		to 	LJ DAC0
//					MFC Pin12 (Signal Common)		to LJ	GND
//  				LJ AIN0 								to LJ DAC0 (To check signal is being sent)

//				MFC Power Supply (PS) Wiring
//					MFC Pin6 (-15V DC) to PS -15V
//					MFC Pin7 (+15V DC) to PS +15V
//					MFC Pin5 (Power Common) to PS Ground

// To access panel, run initLabjackPanel_MFC() in command line. Then, MFC_Panel() or Windows>PanelMacros>MFC_Panel



//===========Initialize LabJack Panel==========================

Function initLabjackPanel_MFC()
	String oldDF=GetDataFolder(1)
	SetDataFolder root:
	NewDataFolder/O/S Packages
	NewDataFolder/O/S LabJackU6
	String/G sIDMenu="_none_"
	
	
	Variable/G refNum=0
	Variable/G outVolts0=1
	Variable/G outVolts1=1
	Variable/G inVolts=0
	
	Variable/G DAC0=0
	Variable/G outValue0 = -9
	Variable/G outValue1 = -9
	Variable/G outValue2 = -9
	Variable/G outValue3 = -9
	
	
	Variable/G offsetCh0 = 0
	Variable/G rangeCh0=100
	Variable/G slopeCh0=1
	
	Variable/G offsetCh1 = 0
	Variable/G rangeCh1=100
	Variable/G slopeCh1=1
	
	Variable/G offsetCh2 = 0
	Variable/G rangeCh2=100
	Variable/G slopeCh2=1
	
	Variable/G offsetCh3 = 0
	Variable/G rangeCh3=100
	Variable/G slopeCh3=1
	
	
	Variable/G realvalueCh0
	Variable/G realvalueCh1
	Variable/G realvalueCh2
	Variable/G realvalueCh3	
	
	
	String/G fpath
	
	
End

//============Button Controls================================

// Find connected labjacks. Must be pressed to identify labjacks.
Function findLabJacksButtonProc(ba) : ButtonControl 
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			String oldDF=GetDataFolder(1)
			SetDataFolder root:Packages:LabJackU6
			Variable err=LJ_ListAll(6, 1)
			if( err == 0 )
				Wave WLJ_pIDs
				SVAR sIDMenu
				sIDMenu = ""
				Variable i,numPoints=numpnts(WLJ_pIDs)
				if( numPoints <= 0 )
					sIDMenu="_none_"
				else
					for(i=0; i<numpoints; i+=1)
						sIDMenu += num2str(WLJ_pIDs[i]) + ";"
					endfor
				endif
			endif
			SetDataFolder oldDF
		break
	endswitch

	return 0
End

//Drop down menu to select labjack

Function openDevicePopMenuProc(pa) : PopupMenuControl  
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum=pa.popNum
			String popStr=pa.popStr
			String oldDF=GetDataFolder(1)
			SetDataFolder root:Packages:LabJackU6
			NVAR refNum
			variable lRefNum
			Wave/T/Z WLJ_addresses
			if( WaveExists(WLJ_addresses) ) 
				Variable err=LJ_OpenLabJack(LJ_dtU6, LJ_ctUSB, popStr, 0, lRefNum)
				if( err )
					Printf "Error %d\r", err
				else
					refNum=lRefNum
					Printf "Opened U6; Driver version=%.2f\r", LJ_DriverVersion()
				endif
			else
				doAlert 0, "You must first search for devices."
			endif
			SetDataFolder oldDF
		break
	endswitch

	return 0
End

//resets labjack numbers

Function resetButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			NVAR refNum=root:Packages:LabJackU6:refNum
			LJ_ResetLabJack(refNum)
			break
	endswitch

	return 0
End

//sets outvolts for MFC 0 (Connected to DAC0)
Function setDAC0SetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval0=sva.dval
			NVAR refNum=root:Packages:LabJackU6:refNum
			LJ_eDac(refNum, 0, dval0, 0)
			
		
			break
	endswitch

	return 0
End

//sets outvolts for MFC 1 (Connected to DAC1)

Function setDAC1SetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval1=sva.dval
			NVAR refNum=root:Packages:LabJackU6:refNum
			LJ_eDac(refNum, 1, dval1, 0)
			break
	endswitch

	return 0
End


//Starts read and panel update
Function StartreadButtonProc(ba) : ButtonControl 
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable numTicks = 60 // Run every 1 second (60 ticks)
			CtrlNamedBackground LabJack, period=numTicks, proc = PingLabJack_nowrite
			CtrlNamedBackground LabJack, start
		break
	endswitch

	return 0
End


//Starts writing data to file (chosen via dialog)
Function StartwriteButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
				String/G fpath = CreateAfile()
			
			Variable numTicks = 60 // Run every 1 second (60 ticks)
			CtrlNamedBackground LabJack, period=numTicks, proc = PingLabJack_write
			CtrlNamedBackground LabJack, start
		break
	endswitch

	return 0
End

//Stops live updates and writing
Function StopreadButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CtrlNamedBackground LabJack, stop
		break
	endswitch

	return 0
End

//Scan MFC Buttons

Function StartMFCScanButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			NVAR refNum=root:Packages:LabJackU6:refNum
			NVAR outvolts0 = root:Packages:LabJackU6:outVolts0  
			outvolts0 = 0 
									
			StepUpMFC()
		break
	endswitch

	return 0
End


Function StopMFCScanButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
				CtrlNamedBackground MFCStep, stop
		break
	endswitch

	return 0
End



//===========Error Handler==========================




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




// Update Panel with read values without datalogging
// Useful when you do not need a data record


Function PingLabJack_nowrite(s)

	STRUCT WMBackgroundStruct &s
	
	Variable outValue
	NVAR refNum=root:Packages:LabJackU6:refNum
	
	NVAR outvalue0 = root:Packages:LabJackU6:outValue0		
	NVAR outvalue1 = root:Packages:LabJackU6:outValue1			
	NVAR offsetCh1=root:Packages:LabJackU6:offsetCh1
	NVAR rangeCh1=root:Packages:LabJackU6:rangeCh1
	NVAR realvalueCh1=root:Packages:LabJackU6:realvalueCh1	
	NVAR slopeCh1= root:Packages:LabJackU6:slopeCh1
	
	
	
	Variable err=LJ_eAIN(refNum, 0, 0, LJ_rgUNI5V, 0, 1, 0, outValue)
	outvalue0 = outValue
			
	err=LJ_eAIN(refNum, 1, 0, LJ_rgUNI5V, 0, 1, 0, outValue)
	outvalue1 = outValue
	realvalueCh1 = (outvalue1*rangeCh1/5 - offsetCh1) /slopeCh1  // MFC controller range is 5V. 
	
	NVAR outvalue2 = root:Packages:LabJackU6:outValue2
			
	NVAR outvalue3 = root:Packages:LabJackU6:outValue3			
	NVAR offsetCh3=root:Packages:LabJackU6:offsetCh3
	NVAR rangeCh3=root:Packages:LabJackU6:rangeCh3
	NVAR slopeCh3= root:Packages:LabJackU6:slopeCh3
	NVAR realvalueCh3=root:Packages:LabJackU6:realvalueCh3	
			
	err=LJ_eAIN(refNum, 2, 0, LJ_rgUNI5V, 0, 1, 0, outValue)
	outvalue2 = outValue
			
	err=LJ_eAIN(refNum, 3, 0, LJ_rgUNI5V, 0, 1, 0, outValue)
	outvalue3 = outValue
	realvalueCh3 = (outvalue3*rangeCh1/5 - offsetCh3) /slopeCh3
	
 	
   	//Updates the panel so you can see current values
	ControlUpdate/A/W=Panel0

	// background functions need to return 0 to continuously run
	return 0
End

// Update Panel with read values with datalogging


Function PingLabJack_write(s)

	STRUCT WMBackgroundStruct &s
	
	Variable outValue
	NVAR refNum=root:Packages:LabJackU6:refNum
	SVAR fpath = root:Packages:LabJackU6:fpath
	
	NVAR outvalue0 = root:Packages:LabJackU6:outValue0		
	NVAR outvalue1 = root:Packages:LabJackU6:outValue1			
	NVAR offsetCh1=root:Packages:LabJackU6:offsetCh1
	NVAR rangeCh1=root:Packages:LabJackU6:rangeCh1
	NVAR slopeCh1= root:Packages:LabJackU6:slopeCh1
	NVAR realvalueCh1=root:Packages:LabJackU6:realvalueCh1	
	
	
	
	Variable err=LJ_eAIN(refNum, 0, 0, LJ_rgUNI5V, 0, 1, 0, outValue)
	outvalue0 = outValue
			
	err=LJ_eAIN(refNum, 1, 0, LJ_rgUNI5V, 0, 1, 0, outValue)
	outvalue1 = outValue
	realvalueCh1 = (outvalue1*rangeCh1/5 - offsetCh1) /slopeCh1
	
	NVAR outvalue2 = root:Packages:LabJackU6:outValue2
	
	
	NVAR outvalue3 = root:Packages:LabJackU6:outValue3			
	NVAR offsetCh3=root:Packages:LabJackU6:offsetCh3
	NVAR rangeCh3=root:Packages:LabJackU6:rangeCh3
	NVAR slopeCh3= root:Packages:LabJackU6:slopeCh3
	NVAR realvalueCh3=root:Packages:LabJackU6:realvalueCh3	
			
	err=LJ_eAIN(refNum, 2, 0, LJ_rgUNI5V, 0, 1, 0, outValue)
	outvalue2 = outValue
	
			
	err=LJ_eAIN(refNum, 3, 0, LJ_rgUNI5V, 0, 1, 0, outValue)
	outvalue3 = outValue
	realvalueCh3 = (outvalue3*rangeCh3/5 - offsetCh3) /slopeCh3
	
	// If you change variables, change the header in the CreateAFile function below

	//Makes the string to print in the datafile. Includes IGOR time, String Date, String Time, Voltage and Converted Values
	String stringtoprint = num2istr(datetime) + "," + secs2date(datetime,-2) + "," + secs2time(datetime, 3) + "," + num2str(refNum) +"," + num2str(outvalue0)+ "," + num2str(outvalue1) + "," + num2str(realvalueCh1) + "," + num2str(outvalue2)+ "," + num2str(outvalue3) + "," + num2str(realvalueCh3) +"\r"
		
	//Adds that string to the file
   	AddToFile(fpath, stringtoprint)
 	
   	//Updates the panel so you can see current values
	ControlUpdate/A/W=Panel0

	// background functions need to return 0 to continuously run
	return 0
End


//===========File Writing===================

Function/S CreateAFile()
    Variable refnum
    Open refnum
    if (refnum)
        fprintf refnum, "IgorTime, Date, Time, LabJacknum, Ch0Volts, Ch1Volts, Flow_MFC0, Ch2Volts, Ch3Volts, Flow_MFC1 \r"
    endif
    FStatus refnum
    String filepath = S_path+S_fileName
    Close refnum
    return filepath
end

Function AddToFile(String filepath, String thingtoprint)
    Variable refnum
    Open/A refnum as filepath
    if (refnum)
        fprintf refnum, thingtoprint
    endif
    Close refnum
end

//Scanning Voltages

//This function automates the scanning of voltages between 0.5 and 4.5V 
// to do a calibration

Function ScanMFCVolt(s)
		STRUCT WMBackgroundStruct &s

		NVAR refNum=root:Packages:LabJackU6:refNum
		NVAR outVolts0=root:Packages:LabJackU6:outVolts0
		
		NVAR refNum=root:Packages:LabJackU6:refNum
		
		if (outVolts0 < 4.5)
			outVolts0+=0.5
		else
			outVolts0 = 0.5
		print "MFC Scan Done!!"
		
		endif
		
		LJ_eDac(refNum, 0, outVolts0, 0)
		ControlUpdate/A/W=Panel0
		
		return 0
				
End

Function StepUpMFC() 
	
		Variable numTicks = 60*30 // Run every 30s (1s = 60 ticks)
		CtrlNamedBackground MFCStep, period=numTicks, proc = ScanMFCVolt
		CtrlNamedBackground MFCStep, start
End


///Panel Macro


Window MFC_Panel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(888,55,1654,447)
	ShowTools/A
	SetDrawLayer UserBack
	DrawRect 33,90,377,278
	SetDrawEnv fsize= 28
	DrawText 163,123,"\\f03MFC 0"
	DrawRect 397,90,741,278
	SetDrawEnv fsize= 28
	DrawText 526,124,"\\f03MFC 1"
	DrawRect 33,294,377,376
	SetDrawEnv fsize= 16
	DrawText 124,323,"\\f01Updates and Logging"
	DrawRect 397,294,741,376
	SetDrawEnv fsize= 16
	DrawText 498,323,"\\f01Scan MFC voltages"
	Button wmFindLabJacks,pos={272.00,21.00},size={174.00,30.00},proc=findLabJacksButtonProc,title="Find LabJacks"
	Button wmFindLabJacks,fSize=20,fStyle=1
	PopupMenu wmLJIDPop,pos={296.00,60.00},size={140.00,25.00},proc=openDevicePopMenuProc,title="Select Device:"
	PopupMenu wmLJIDPop,fSize=18
	PopupMenu wmLJIDPop,mode=1,popvalue="1",value= #"root:Packages:LabJackU6:sIDMenu"
	Button ljResetButton,pos={490.00,64.00},size={67.00,20.00},proc=resetButtonProc,title="Reset"
	Button button0,pos={44.00,328.00},size={150.00,20.00},proc=StartreadButtonProc,title="Start Live Updates"
	SetVariable outVolts_DAC,pos={48.00,136.00},size={144.00,26.00},proc=setDAC0SetVarProc,title="Set OutVolts"
	SetVariable outVolts_DAC,labelBack=(32768,65535,49386),fSize=16,fStyle=1
	SetVariable outVolts_DAC,limits={0,5,0.1},value= root:Packages:LabJackU6:outVolts0,live= 1
	ValDisplay valdisp4,pos={201.00,144.00},size={150.00,18.00},title="Read OutVolts"
	ValDisplay valdisp4,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp4,value= #"root:Packages:LabJackU6:outvalue0"
	Button button6,pos={130.00,353.00},size={150.00,20.00},proc=StopreadButtonProc,title="Stop Updates or Writing"
	Button button7,pos={198.00,328.00},size={150.00,20.00},proc=StartwriteButtonProc,title="Start Writing"
	Button button8,pos={414.00,335.00},size={150.00,20.00},proc=StartMFCScanButtonProc,title="Start"
	Button button9,pos={567.00,335.00},size={150.00,20.00},proc=StopMFCScanButtonProc,title="Stop"
	SetVariable outVolts_DAC2,pos={411.00,136.00},size={144.00,26.00},proc=setDAC1SetVarProc,title="Set OutVolts"
	SetVariable outVolts_DAC2,labelBack=(32768,65535,49386),fSize=16,fStyle=1
	SetVariable outVolts_DAC2,limits={0,5,0.1},value= root:Packages:LabJackU6:outVolts1,live= 1
	ValDisplay valdisp5,pos={580.00,144.00},size={150.00,18.00},title="Read OutVolts"
	ValDisplay valdisp5,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp5,value= #"root:Packages:LabJackU6:outvalue2"
	SetVariable setvar6,pos={216.00,181.00},size={80.00,19.00},title="Offset"
	SetVariable setvar6,limits={-inf,inf,0},value= root:Packages:LabJackU6:offsetCh1
	ValDisplay valdisp8,pos={125.00,242.00},size={160.00,30.00},title="Flow"
	ValDisplay valdisp8,fSize=20,fStyle=1,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp8,value= #"root:Packages:LabJackU6:realvalueCh1"
	SetVariable setvar05,pos={68.00,184.00},size={80.00,19.00},title="Range"
	SetVariable setvar05,limits={-inf,inf,0},value= root:Packages:LabJackU6:rangeCh1
	SetVariable setvar06,pos={216.00,202.00},size={80.00,19.00},title="Slope "
	SetVariable setvar06,limits={-inf,inf,0},value= root:Packages:LabJackU6:slopeCh1
	ValDisplay valdisp9,pos={488.00,242.00},size={160.00,30.00},title="Flow"
	ValDisplay valdisp9,fSize=20,fStyle=1,limits={0,0,0},barmisc={0,1000}
	ValDisplay valdisp9,value= #"root:Packages:LabJackU6:realvalueCh3"
	SetVariable setvar01,pos={590.00,181.00},size={80.00,19.00},title="Offset"
	SetVariable setvar01,limits={-inf,inf,0},value= root:Packages:LabJackU6:offsetCh3
	SetVariable setvar02,pos={440.00,184.00},size={80.00,19.00},title="Range"
	SetVariable setvar02,limits={-inf,inf,0},value= root:Packages:LabJackU6:rangeCh3
	SetVariable setvar03,pos={590.00,202.00},size={80.00,19.00},title="Slope "
	SetVariable setvar03,limits={-inf,inf,0},value= root:Packages:LabJackU6:slopeCh3
EndMacro