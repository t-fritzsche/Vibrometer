function[Settings]=configureDevices(Settings,sAxis,visaOszi,sFG,sVibrometer)
% Communicate and set the configurations in 'Settings' for the external devices
% 	- Function generator (for excitation of the transducer)
% 	- Oscilloscope
% 	- x-y-stage (for the positioning of the transducer)
% 	- Vibrometer 
%
%
%% Configure the Function Generator
%set frequency, voltage from settings. Offset is 0, and channel is 1
 fprintf(sFG,'OUTPut1:LOAD INFinity'); %set impedance to 1Meg ohm
 operationComplete = str2double(query(sFG,'*OPC?'));
while ~(operationComplete==1)
    operationComplete = str2double(query(sFG,'*OPC?'));
     pause(0.01);
end
 fprintf(sFG,['SOUR1:APPL:SIN ' num2str(Settings.FGen.Freq) 'KHZ,' num2str(Settings.FGen.Vpp) ',0']);
 pause(0.5);
operationComplete = str2double(query(sFG,'*OPC?'));
while ~(operationComplete==1)
    operationComplete = str2double(query(sFG,'*OPC?'));
     pause(0.01);
end
fprintf(sFG,'SYST:LOC'); %allow the user to change the settings afterwards
%% Configure the oszilloscope
% Scope settings
scope.averaging = 1024; % 2,4,8,16,32,64,128
scope.bw = 5E6;
scope.skipAfterAutoscale=0;
% Reset the instrument and autoscale and stop
% fprintf(visaOszi,'*RST');
fprintf(visaOszi,':SYSTem:PREset');
fprintf(visaOszi,':STOP');

if Settings.Oszi.AutoSettings
    %Autoscale oszilloscope is selected
    %1. do a auto-setup 
    %2. and a single measurementdd
    %3. calculate and set the scale of the oszilloscope
    %4. save the range in the "Settings" file
    %5. set the interface values accordingly
    %6. continue with the rest of the initialization
    fprintf(visaOszi,':AUToscale');
    %do a single measurement and set the range accordingly
    [Settings.Oszi.CH1Res,Settings.Oszi.CH2Res]=adjustOsziScale(visaOszi);
    
end

%SET THE REMAINING VALUES
% Channel 1
if Settings.Oszi.CH1EN
    fprintf(visaOszi,':CHAN1:BWLimit 0'); %enable low pass filter
    fprintf(visaOszi,[':CHAN1:BANDwidth ' num2str(scope.bw)]);%set BW
    fprintf(visaOszi,':CHAN1:COUP AC');
    fprintf(visaOszi,':CHAN1:DISPlay 1'); %show the waveform
    fprintf(visaOszi,':CHAN1:OFFS 0.00');
    fprintf(visaOszi,':CHAN1:PROB 1');
    fprintf(visaOszi,':CHAN1:RANGe 10');
    fprintf(visaOszi,[':CHAN1:SCAL ' num2str(Settings.Oszi.CH1Res) 'V']);
    fprintf(visaOszi,':CHAN1:UNITs VOLT'); %hinzugef�gt
    fprintf(visaOszi,':CHAN1:VERNier 0'); %hinzugef�gt fine vertical adjustment
else
    fprintf(visaOszi,':CHAN1:DISPlay 0'); %show the waveform
end

% Channel 2
if Settings.Oszi.CH2EN
    fprintf(visaOszi,':CHAN2:BWLimit 0'); %enable low pass filter
    fprintf(visaOszi,[':CHAN2:BANDwidth ' num2str(scope.bw)]);%set BW
    fprintf(visaOszi,':CHAN2:COUP AC');
    fprintf(visaOszi,':CHAN2:DISPlay 1'); %show the waveform
    fprintf(visaOszi,':CHAN2:OFFS 0.00');
    fprintf(visaOszi,':CHAN2:PROB 1');
    fprintf(visaOszi,':CHAN2:RANGe 10');
    fprintf(visaOszi,[':CHAN2:SCAL ' num2str(Settings.Oszi.CH2Res) 'V']);
    fprintf(visaOszi,':CHAN2:UNITs VOLT'); %hinzugef�gt
    fprintf(visaOszi,':CHAN2:VERNier 0'); %hinzugef�gt fine vertical adjustment
else
    fprintf(visaOszi,':CHAN2:DISPlay 0'); %show the waveform
end

% Time settings
fprintf(visaOszi,':TIM:MODE NORM'); 
if Settings.Oszi.SelTBFromFG %calculate them from the function generator value
    Settings.Oszi.TimeBase = round(180/(Settings.FGen.Freq),2,'significant'); %in �s
end

fprintf(visaOszi,[':TIM:SCAL ' num2str(Settings.Oszi.TimeBase*1E-06)]) ;

   
 
% Measurements on display
for i=1:4
    if ~(strcmp(Settings.Oszi.Aq{i}.Str,'') || strcmp(Settings.Oszi.Aq{i}.Str,''))
        fprintf(visaOszi,[':MEASure:' Settings.Oszi.Aq{i}.Str])
   end
end

%Trigger mode
fprintf(visaOszi,':TRIGger:MODE EDGE');
fprintf(visaOszi,':TRIGger:SWEep NORMal');
%fprintf(visaOszi,':TRIGger:LEVel:ASETup'); %still not fully functional

%Aquisition. Either use the AVERage mode with Count OR the HRESolution!
%fprintf(visaOszi,':ACQUIRE:TYPE HRESolution');
fprintf(visaOszi,':ACQuire:TYPE AVERage');
fprintf(visaOszi,[':ACQuire:COUNt ' num2str(scope.averaging)]);
fprintf(visaOszi,':ACQuire:COMPlete 100');   %the buffer has to be filled 100%

scope.sampleRate = str2double(query(visaOszi,':ACQUIRE:SRAT?')); 
operationComplete1 = str2double(query(visaOszi,'*OPC?'));
while ~(operationComplete1)
    operationComplete1 = str2double(query(visaOszi,'*OPC?'));
end

fprintf(visaOszi,':WAV:POINTS:MODE MAX'); %Seite 281/282 bzgl NORM und RAW
scope.points = str2double(query(visaOszi,':ACQuire:POINts?'));


%% configure the vibrometer
%set the mode toe 'remote' so the settings can be controlled either by
%matlab or manually by the user
fprintf(sVibrometer,'REN');

if Settings.Vib.AutoSettings
    %we should determin the best settings ourselves
    [VelocityResValue]=determineBestVibrometerRange(sVibrometer);
    %save the value again in the settings
    switch VelocityResValue
        case 1
            Settings.Vib.VelResNR=1;
        case 5
            Settings.Vib.VelResNR=2;
        case 25
            Settings.Vib.VelResNR=3;
        case 125
            Settings.Vib.VelResNR=4;
        case 1000
            Settings.Vib.VelResNR=5;
    end
    
%     fprintf(sVibrometer,'VELO5');
%     currVelo=5;
%     if str2double(query(sVibrometer,'OVR'))==1
%         fprintf(sVibrometer,'VELO1');
%         currVelo=1;
%         while ((str2double(query(sVibrometer,'OVR'))==1)&&currVelo<=4)
%             currVelo=currVelo+1;
%             fprintf(sVibrometer,['VELO' num2str(currVelo)]);
%             currVelo=str2double(query(sVibrometer,'VELO?'));
%         end
%     end
%     %save the value again in the settings
%     switch VelocityResValue
%         case 1
%             Settings.Vib.VelResNR=1;
%         case 5
%             Settings.Vib.VelResNR=2;
%         case 25
%             Settings.Vib.VelResNR=3;
%         case 125
%             Settings.Vib.VelResNR=4;
%         case 1000
%             Settings.Vib.VelResNR=5;
%     end
else
    %use the saved settings
    switch Settings.Vib.VelResNR
        case 1 %= 1mm/s/V is setting Nr 5 at Vibrometer
            fprintf(sVibrometer,'VELO5');
        case 2 %= 5mm/s/V is setting Nr 1 at Vibrometer
            fprintf(sVibrometer,'VELO1');
        case 3 %= 25mm/s/V is setting Nr 2 at Vibrometer
            fprintf(sVibrometer,'VELO2');
        case 4 %= 125mm/s/V is setting Nr 3 at Vibrometer
            fprintf(sVibrometer,'VELO3');
        case 5 %= 1000mm/s/V is setting Nr 4 at Vibrometer
            fprintf(sVibrometer,'VELO4');
    end
end
