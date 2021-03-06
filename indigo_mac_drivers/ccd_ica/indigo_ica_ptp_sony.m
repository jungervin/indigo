//
//  indigo_ica_sony.m
//  IndigoApps
//
//  Created by Peter Polakovic on 11/07/2017.
//  Copyright © 2017 CloudMakers, s. r. o. All rights reserved.
//

#include "indigo_bus.h"

#import "indigo_ica_ptp_sony.h"

static PTPSonyProperty *ptpReadSonyProperty(unsigned char** buf) {
  unsigned int code = ptpReadUnsignedShort(buf);
  PTPSonyProperty *property = [[PTPSonyProperty alloc] initWithCode:code];
  property.type = ptpReadUnsignedShort(buf);
  //property.readOnly = false; 
  property.readOnly = !ptpReadUnsignedChar(buf);
  ptpReadUnsignedChar(buf);
  property.defaultValue = ptpReadValue(property.type, buf);
  property.value = ptpReadValue(property.type, buf);

  int form = ptpReadUnsignedChar(buf);
  switch (form) {
    case 1: {
      property.min = (NSNumber *)ptpReadValue(property.type, buf);
      property.max = (NSNumber *)ptpReadValue(property.type, buf);
      property.step = (NSNumber *)ptpReadValue(property.type, buf);
      break;
    }
    case 2: {
      int count = ptpReadUnsignedShort(buf);
      NSMutableArray<NSObject*> *values = [NSMutableArray arrayWithCapacity:count];
      for (int i = 0; i < count; i++)
        [values addObject:ptpReadValue(property.type, buf)];
      property.supportedValues = values;
      break;
    }
  }
  
  return property;
}


@implementation PTPSonyRequest

+(NSString *)operationCodeName:(PTPRequestCode)operationCode {
  switch (operationCode) {
    case PTPRequestCodeSonySDIOConnect: return @"PTPRequestCodeSonySDIOConnect";
    case PTPRequestCodeSonyGetSDIOGetExtDeviceInfo: return @"PTPRequestCodeSonyGetSDIOGetExtDeviceInfo";
    case PTPRequestCodeSonyGetDevicePropDesc: return @"PTPRequestCodeSonyGetDevicePropDesc";
    case PTPRequestCodeSonyGetDevicePropertyValue: return @"PTPRequestCodeSonyGetDevicePropertyValue";
    case PTPRequestCodeSonySetControlDeviceA: return @"PTPRequestCodeSonySetControlDeviceA";
    case PTPRequestCodeSonyGetControlDeviceDesc: return @"PTPRequestCodeSonyGetControlDeviceDesc";
    case PTPRequestCodeSonySetControlDeviceB: return @"PTPRequestCodeSonySetControlDeviceB";
    case PTPRequestCodeSonyGetAllDevicePropData: return @"PTPRequestCodeSonyGetAllDevicePropData";
  }
  return [PTPRequest operationCodeName:operationCode];
}

-(NSString *)operationCodeName {
  return [PTPSonyRequest operationCodeName:self.operationCode];
}

@end

@implementation PTPSonyResponse

+ (NSString *)responseCodeName:(PTPResponseCode)responseCode {
  return [PTPResponse responseCodeName:responseCode];
}

-(NSString *)responseCodeName {
  return [PTPSonyResponse responseCodeName:self.responseCode];
}

@end

@implementation PTPSonyEvent

+(NSString *)eventCodeName:(PTPEventCode)eventCode {
  switch (eventCode) {
    case PTPEventCodeSonyObjectAdded: return @"PTPEventCodeSonyObjectAdded";
    case PTPEventCodeSonyObjectRemoved: return @"PTPEventCodeSonyObjectRemoved";
    case PTPEventCodeSonyPropertyChanged: return @"PTPEventCodeSonyPropertyChanged";
  }
  return [PTPEvent eventCodeName:eventCode];
}

-(NSString *)eventCodeName {
  return [PTPSonyEvent eventCodeName:self.eventCode];
}

@end

@implementation PTPSonyProperty : PTPProperty

+(NSString *)propertyCodeName:(PTPPropertyCode)propertyCode {
  switch (propertyCode) {
    case PTPPropertyCodeSonyDPCCompensation: return @"PTPPropertyCodeSonyDPCCompensation";
    case PTPPropertyCodeSonyDRangeOptimize: return @"PTPPropertyCodeSonyDRangeOptimize";
    case PTPPropertyCodeSonyImageSize: return @"PTPPropertyCodeSonyImageSize";
    case PTPPropertyCodeSonyShutterSpeed: return @"PTPPropertyCodeSonyShutterSpeed";
    case PTPPropertyCodeSonyColorTemp: return @"PTPPropertyCodeSonyColorTemp";
    case PTPPropertyCodeSonyCCFilter: return @"PTPPropertyCodeSonyCCFilter";
    case PTPPropertyCodeSonyAspectRatio: return @"PTPPropertyCodeSonyAspectRatio";
    case PTPPropertyCodeSonyFocusStatus: return @"PTPPropertyCodeSonyFocusStatus";
    case PTPPropertyCodeSonyExposeIndex: return @"PTPPropertyCodeSonyExposeIndex";
    case PTPPropertyCodeSonyPictureEffect: return @"PTPPropertyCodeSonyPictureEffect";
    case PTPPropertyCodeSonyABFilter: return @"PTPPropertyCodeSonyABFilter";
    case PTPPropertyCodeSonyISO: return @"PTPPropertyCodeSonyISO";
    case PTPPropertyCodeSonyAutofocus: return @"PTPPropertyCodeSonyAutofocus";
    case PTPPropertyCodeSonyCapture: return @"PTPPropertyCodeSonyCapture";
    case PTPPropertyCodeSonyMovie: return @"PTPPropertyCodeSonyMovie";
    case PTPPropertyCodeSonyStillImage: return @"PTPPropertyCodeSonyStillImage";
  }
  return [PTPProperty propertyCodeName:propertyCode];
}

-(NSString *)propertyCodeName {
  return [PTPSonyProperty propertyCodeName:self.propertyCode];
}

@end


@implementation PTPSonyDeviceInfo

-(NSString *)debug {
  NSMutableString *s = [NSMutableString stringWithFormat:@"%@ %@, PTP V%.2f + %@ V%.2f\n", self.model, self.version, self.standardVersion / 100.0, self.vendorExtensionDesc, self.vendorExtensionVersion / 100.0];
  if (self.operationsSupported.count > 0) {
    for (NSNumber *code in self.operationsSupported)
      [s appendFormat:@"%@\n", [PTPSonyRequest operationCodeName:code.intValue]];
  }
  if (self.eventsSupported.count > 0) {
    for (NSNumber *code in self.eventsSupported)
      [s appendFormat:@"%@\n", [PTPSonyEvent eventCodeName:code.intValue]];
  }
  if (self.propertiesSupported.count > 0) {
    for (NSNumber *code in self.propertiesSupported) {
      PTPProperty *property = self.properties[code];
      if (property)
        [s appendFormat:@"%@\n", property];
      else
        [s appendFormat:@"%@\n", [PTPSonyProperty propertyCodeName:code.intValue]];
    }
  }
  return s;
}
@end

@implementation PTPSonyCamera {
  unsigned int compression;
  unsigned int format;
  unsigned int imageCount;
  unsigned short mode;
  bool waitForCapture;
  unsigned int shutterSpeed;
  unsigned int focusMode;
  PTPPropertyCode iteratedProperty;
}

-(NSString *)name {
  return [NSString stringWithFormat:@"Sony %@", super.name];
}

-(PTPVendorExtension) extension {
  return PTPVendorExtensionSony;
}

-(id)initWithICCamera:(ICCameraDevice *)icCamera delegate:(NSObject<PTPDelegateProtocol> *)delegate {
  self = [super initWithICCamera:icCamera delegate:delegate];
  if (self) {
  }
  return self;
}

-(void)didRemoveDevice:(ICDevice *)device {
  [super didRemoveDevice:device];
}


-(Class)requestClass {
  return PTPSonyRequest.class;
}

-(Class)responseClass {
  return PTPSonyResponse.class;
}

-(Class)eventClass {
  return PTPSonyEvent.class;
}

-(Class)propertyClass {
  return PTPSonyProperty.class;
}

-(Class)deviceInfoClass {
  return PTPSonyDeviceInfo.class;
}

-(void)checkForEvent {
}

-(void)processEvent:(PTPEvent *)event {
  switch (event.eventCode) {
    case PTPEventCodeSonyPropertyChanged: {
      if (iteratedProperty == 0)
        [self sendPTPRequest:PTPRequestCodeSonyGetAllDevicePropData];
      break;
    }
    case PTPEventCodeSonyObjectAdded: {
      if (compression == 19)
        imageCount = 2;
      else
        imageCount = 1;
      [self sendPTPRequest:PTPRequestCodeGetObjectInfo param1:event.parameter1];
      break;
    }
    default: {
      [super processEvent:event];
      break;
    }
  }
}

-(void)processPropertyDescription:(PTPProperty *)property {
  switch (property.propertyCode) {
    case PTPPropertyCodeSonyDPCCompensation: {
//      NSArray *values = @[ @"3000", @"2700", @"2500", @"2300", @"2000", @"1700", @"1500", @"1300", @"1000", @"700", @"500", @"300", @"0", @"-300", @"-500", @"-700", @"-1000", @"-1300", @"-1500", @"-1700", @"-2000", @"-2300", @"-2500", @"-2700", @"-3000" ];
//      NSArray *labels = @[ @"+3", @"+2 2/3", @"+2 1/2", @"+2 1/3", @"+2", @"+1 2/3", @"+1 1/2", @"+1 1/3", @"+1", @"+2/3", @"+1/2", @"+1/3", @"0", @"-1/3", @"-1/2", @"-2/3", @"-1", @"-1 1/3", @"-1 1/2", @"-1 2/3", @"-2", @"-2 1/3", @"-2 1/2", @"-2 2/3", @"-3" ];
      NSArray *values = @[ @"3000", @"2700", @"2300", @"2000", @"1700", @"1300", @"1000", @"700", @"300", @"0", @"-300", @"-700", @"-1000", @"-1300", @"-1700", @"-2000", @"-2300", @"-2700", @"-3000" ];
      NSArray *labels = @[ @"+3", @"+2 2/3", @"+2 1/3", @"+2", @"+1 2/3", @"+1 1/3", @"+1", @"+2/3", @"+1/3", @"0", @"-1/3", @"-2/3", @"-1", @"-1 1/3", @"-1 2/3", @"-2", @"-2 1/3", @"-2 2/3", @"-3" ];
      property.readOnly = mode != 2 && mode != 3 && mode != 4 && mode != 1 && mode != 32848 && mode != 32849 && mode != 32850 && mode != 32851;
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeExposureBiasCompensation: {
//      NSArray *values = @[ @"5000", @"4700", @"4500", @"4300", @"4000", @"3700", @"3500", @"3300", @"3000", @"2700", @"2500", @"2300", @"2000", @"1700", @"1500", @"1300", @"1000", @"700", @"500", @"300", @"0", @"-300", @"-500", @"-700", @"-1000", @"-1300", @"-1500", @"-1700", @"-2000", @"-2300", @"-2500", @"-2700", @"-3000", @"-3300", @"-3500", @"-3700", @"-4000", @"-4300", @"-4500", @"-4700", @"-5000" ];
//      NSArray *labels = @[ @"+5", @"+4 2/3", @"+4 1/2", @"+4 1/3", @"+4", @"+3 2/3", @"+3 1/2", @"+3 1/3", @"+3", @"+2 2/3", @"+2 1/2", @"+2 1/3", @"+2", @"+1 2/3", @"+1 1/2", @"+1 1/3", @"+1", @"+2/3", @"+1/2", @"+1/3", @"0", @"-1/3", @"-1/2", @"-2/3", @"-1", @"-1 1/3", @"-1 1/2", @"-1 2/3", @"-2", @"-2 1/3", @"-2 1/2", @"-2 2/3", @"-3", @"-3 1/3", @"-3 1/2", @"-3 2/3", @"-4", @"-4 1/3", @"-4 1/2", @"-4 2/3", @"-5" ];
      NSArray *values = @[ @"5000", @"4700", @"4300", @"4000", @"3700", @"3300", @"3000", @"2700", @"2300", @"2000", @"1700", @"1300", @"1000", @"700", @"300", @"0", @"-300", @"-700", @"-1000", @"-1300", @"-1700", @"-2000", @"-2300", @"-2700", @"-3000", @"-3300", @"-3700", @"-4000", @"-4300", @"-4700", @"-5000" ];
      NSArray *labels = @[ @"+5", @"+4 2/3", @"+4 1/3", @"+4", @"+3 2/3",@"+3 1/3", @"+3", @"+2 2/3", @"+2 1/3", @"+2", @"+1 2/3", @"+1 1/3", @"+1", @"+2/3", @"+1/3", @"0", @"-1/3", @"-2/3", @"-1", @"-1 1/3", @"-1 2/3", @"-2", @"-2 1/3", @"-2 2/3", @"-3", @"-3 1/3", @"-3 2/3", @"-4", @"-4 1/3", @"-4 2/3", @"-5" ];
      property.readOnly = mode != 2 && mode != 3 && mode != 4 && mode != 32848 && mode != 32849 && mode != 32850 && mode != 32851;
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeStillCaptureMode: {
      NSDictionary *map = @{ @1: @"Single shooting", @32787: @"Cont. shooting", @32788: @"Spd priority cont.", @32773: @"Self-timer 2s", @32772: @"Self-time 10s", @32776: @"Self-timer 10s 3x", @32777: @"Self-timer 10s 5x", @33591: @"Bracket 1/3EV 3x cont.", @33655: @"Bracket 2/3EV 3x cont.", @33553: @"Bracket 1EV 3x cont.", @33569: @"Bracket 2EV 3x cont.", @33585: @"Bracket 3EV 3x cont.", @33590: @"Bracket 1/3EV 3x", @33654: @"Bracket 2/3EV 3x", @33552: @"Bracket 1EV 3x", @33568: @"Bracket 2EV 3x", @33584: @"Bracket 3EV 3x", @32792: @"Bracket WB Lo", @32808: @"Bracket WB Hi", @32793: @"Bracket DRO Lo", @32809: @"Bracket DRO Hi" };
      [self mapValueList:property map:map];
      break;
    }
    case PTPPropertyCodeWhiteBalance: {
      NSDictionary *map = @{ @2: @"Auto", @4: @"Daylight", @32785: @"Shade", @32784: @"Cloudy", @6: @"Incandescent", @32769: @"Flourescent warm white", @32770: @"Flourescent cool white", @32771: @"Flourescent day white", @32772:@"Flourescent daylight",  @7: @"Flash", @32786: @"C.Temp/Filter", @32803: @"Custom" };
      [self mapValueList:property map:map];
      break;
    }
    case PTPPropertyCodeCompressionSetting: {
      compression = property.value.intValue;
      NSDictionary *map = @{ @2: @"Standard", @3: @"Fine", @16: @"RAW", @19: @"RAW + JPEG" };
      [self mapValueList:property map:map];
      break;
    }
    case PTPPropertyCodeExposureMeteringMode: {
      NSArray *values = @[ @"1", @"2", @"4" ];
      NSArray *labels = @[ @"Multi", @"Center", @"Spot" ];
      property.readOnly = false;
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeFNumber: {
      NSArray *values = @[ @"350", @"400", @"450", @"500", @"560", @"630", @"710", @"800", @"900", @"1000", @"1100", @"1300", @"1400", @"1600", @"1800", @"2000", @"2200" ];
      NSArray *labels = @[ @"f/3.5", @"f/4", @"f/4.5", @"f/5", @"f/5.6", @"f/6.3", @"f/7.1", @"f/8", @"f/9", @"f/10", @"f/11", @"f/13", @"f/14", @"f/16", @"f/18", @"f/20", @"f/22" ];
      property.readOnly = mode != 3 && mode != 1 && mode != 32849 && mode != 32851;
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeFocusMode: {
      NSArray *values = @[ @"2", @"32772", @"32774", @"1" ];
      NSArray *labels = @[ @"AF-S", @"AF-C", @"DMF", @"MF" ];
      property.readOnly = mode == 32848 || mode == 32849 || mode == 32850 || mode == 32851;
      focusMode = property.value.intValue;
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeSonyDRangeOptimize: {
      NSDictionary *map = @{ @1:@"Off", @31:@"DRO Auto", @17:@"DRO Lv1", @18:@"DRO Lv2", @19:@"DRO Lv3", @20:@"DRO Lv4", @21:@"DRO Lv1", @32:@"Auto HDR", @33:@"Auto HDR 1.0EV", @34:@"Auto HDR 2.0EV", @35:@"Auto HDR 3.0EV", @36:@"Auto HDR 4.0EV", @37:@"Auto HDR 5.0EV", @38:@"Auto HDR 6.0EV" };
      [self mapValueList:property map:map];
      break;
    }
    case PTPPropertyCodeSonyCCFilter: {
      NSArray *values = @[ @"135", @"134", @"133", @"132", @"131", @"130", @"129", @"128", @"127", @"126", @"125", @"124", @"123", @"122", @"121" ];
      NSArray *labels = @[ @"G7", @"G6", @"G5", @"G4", @"G3", @"G2", @"G1", @"0", @"M1", @"M2", @"M3", @"M4", @"M5", @"M6", @"M7" ];
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeSonyABFilter: {
      NSArray *values = @[ @"135", @"134", @"133", @"132", @"131", @"130", @"129", @"128", @"127", @"126", @"125", @"124", @"123", @"122", @"121" ];
      NSArray *labels = @[ @"A7", @"A6", @"A5", @"A4", @"A3", @"A2", @"A1", @"0", @"B1", @"B2", @"B3", @"B4", @"B5", @"B6", @"B7" ];
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeSonyImageSize: {
      NSDictionary *map = @{ @1: @"Large", @2: @"Medium", @3: @"Small" };
      [self mapValueList:property map:map];
      break;
    }
    case PTPPropertyCodeSonyAspectRatio: {
      NSDictionary *map = @{ @1: @"3:2", @2: @"16:9" };
      [self mapValueList:property map:map];
      break;
    }
    case PTPPropertyCodeSonyPictureEffect: {
      NSDictionary *map = @{ @32768: @"Off", @32769: @"Toy camera - normal", @32770: @"Toy camera - cool", @32771: @"Toy camera - warm", @32772: @"Toy camera - green", @32773: @"Toy camera - magenta", @32784: @"Pop Color", @32800: @"Posterisation B/W", @32801: @"Posterisation Color", @32816: @"Retro", @32832: @"Soft high key", @32848: @"Partial color - red", @32849: @"Partial color - green", @32850: @"Partial color - blue", @32851: @"Partial color - yellow", @32864: @"High contrast mono", @32880: @"Soft focus - low", @32881: @"Soft focus - mid", @32882: @"Soft focus - high", @32896: @"HDR painting - low", @32897: @"HDR painting - mid", @32898: @"HDR painting - high", @32912: @"Rich tone mono", @32928: @"Miniature - auto", @32929: @"Miniature - top", @32930: @"Miniature - middle horizontal", @32931: @"Miniature - bottom", @32932: @"Miniature - right", @32933: @"Miniature - middle vertical", @32934: @"Miniature - left", @32944: @"Watercolor", @32960: @"Illustration - low", @32961: @"Illustration - mid", @32962: @"Illustration - high" };
      [self mapValueList:property map:map];
      break;
    }
    case PTPPropertyCodeSonyISO: {
      NSArray *values = @[ @"16777215", @"100", @"125", @"160", @"200", @"250", @"320", @"400", @"500", @"640", @"800", @"1000", @"1250", @"1600", @"2000", @"2500", @"3200", @"4000", @"5000", @"6400", @"8000", @"10000", @"12800", @"16000" ];
      NSArray *labels = @[ @"Auto", @"100", @"125", @"160", @"200", @"250", @"320", @"400", @"500", @"640", @"800", @"1000", @"1250", @"1600", @"2000", @"2500", @"3200", @"4000", @"5000", @"6400", @"8000", @"10000", @"12800", @"16000" ];
      property.readOnly = mode != 2 && mode != 3 && mode != 4 && mode != 1 && mode != 32848 && mode != 32849 && mode != 32850 && mode != 32851;
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeSonyShutterSpeed: {
      NSArray *values = @[ @"69536", @"68736", @"68036", @"67536", @"67136", @"66786", @"66536", @"66336", @"66176", @"66036", @"65936", @"65856", @"65786", @"65736", @"65696", @"65661", @"65636", @"65616", @"65596", @"65586", @"65576", @"65566", @"65561", @"65556", @"65551", @"65549", @"65546", @"65544", @"65542", @"65541", @"65540", @"65539", @"262154", @"327690", @"393226", @"524298", @"655370", @"851978", @"1048586", @"1310730", @"1638410", @"2097162", @"2621450", @"3276810", @"3932170", @"5242890", @"6553610", @"8519690", @"9830410", @"13107210", @"16384010", @"19660810", @"0" ];
      NSArray *labels = @[ @"1/4000", @"1/3200", @"1/2500", @"1/2000", @"1/1600", @"1/1250", @"1/1000", @"1/800", @"1/600", @"1/500", @"1/400", @"1/320", @"1/250", @"1/200", @"1/160", @"1/125", @"1/100", @"1/80", @"1/60", @"1/50", @"1/40", @"1/30", @"1/25", @"1/20", @"1/15", @"1/13", @"1/10", @"1/8", @"1/6", @"1/5", @"1/4", @"1/3", @"0.4\"", @"0.5\"", @"0.6\"", @"0.8\"", @"1\"", @"1.3\"", @"1.6\"", @"2.0\"", @"2.5\"", @"3.2\"", @"4\"", @"5\"", @"6\"", @"8\"", @"10\"", @"13\"", @"15\"", @"20\"", @"25\"", @"30\"", @"Bulb" ];
      property.readOnly = mode != 4 && mode != 1 && mode != 32850 && mode != 32851;
      shutterSpeed = property.value.intValue;
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeExposureProgramMode: {
      NSArray *values = @[ @"32768", @"32769", @"2", @"3", @"4", @"1", @"32848", @"32849", @"32850", @"32851", @"32852", @"32833", @"7", @"32785", @"32789", @"32788", @"32786", @"32787", @"32790", @"32791", @"32792"];
      NSArray *labels = @[ @"Intelligent auto", @"Superior auto", @"P", @"A", @"S", @"M", @"P - movie", @"A - movie", @"S - movie", @"M - movie", @"0x8054", @"Sweep panorama", @"Portrait", @"Sport", @"Macro", @"Landscape", @"Sunset", @"Night scene", @"Handheld twilight", @"Night portrait", @"Anti motion blur" ];
      [self.delegate cameraPropertyChanged:self code:property.propertyCode value:property.value.description values:values labels:labels readOnly:property.readOnly];
      break;
    }
    case PTPPropertyCodeFlashMode: {
      NSDictionary *map = @{ @0: @"Undefined", @1: @"Automatic flash", @2: @"Flash off", @3: @"Fill flash", @4: @"Automatic Red-eye Reduction", @5: @"Red-eye fill flash", @6: @"External sync", @0x8032: @"Slow Sync", @0x8003: @"Reer Sync" };
      [self mapValueList:property map:map];
      break;
    }
    case PTPPropertyCodeSonyFocusStatus: {
      [super processPropertyDescription:property];
      if (focusMode == 1)
        break;
      switch (property.value.intValue) {
        case 2:     // AFS
        case 6: {   // AFC
          if (waitForCapture) {
            waitForCapture = false;
            [self setProperty:PTPPropertyCodeSonyCapture value:@"2"];
            if (shutterSpeed) {
              [self setProperty:PTPPropertyCodeSonyCapture value:@"1"];
              [self setProperty:PTPPropertyCodeSonyAutofocus value:@"1"];
            }
          } else {
            [self setProperty:PTPPropertyCodeSonyAutofocus value:@"1"];
          }
          break;
        }
        case 3: {
          if (waitForCapture) {
            waitForCapture = false;
            [self.delegate cameraExposureFailed:self message:@"Failed to focus"];
          }
          [self setProperty:PTPPropertyCodeSonyAutofocus value:@"1"];
        }
      }
      break;
    }
    default: {
      [super processPropertyDescription:property];
      break;
    }
  }
}

-(void)processConnect {
  if ([self propertyIsSupported:PTPPropertyCodeSonyStillImage])
    [self.delegate cameraCanExposure:self];
  [super processConnect];
}

-(void)processRequest:(PTPRequest *)request Response:(PTPResponse *)response inData:(NSData*)data {
  switch (request.operationCode) {
    case PTPRequestCodeGetDeviceInfo: {
      if (response.responseCode == PTPResponseCodeOK && data) {
        self.info = [[self.deviceInfoClass alloc] initWithData:data];
        for (NSNumber *code in self.info.propertiesSupported)
          [self sendPTPRequest:PTPRequestCodeGetDevicePropDesc param1:code.unsignedShortValue];
        if ([self operationIsSupported:PTPRequestCodeSonyGetSDIOGetExtDeviceInfo]) {
          [self sendPTPRequest:PTPRequestCodeSonySDIOConnect param1:1 param2:0 param3:0];
          [self sendPTPRequest:PTPRequestCodeSonySDIOConnect param1:2 param2:0 param3:0];
          [self sendPTPRequest:PTPRequestCodeSonyGetSDIOGetExtDeviceInfo param1:0xC8];
        } else {
          [self sendPTPRequest:PTPRequestCodeGetStorageIDs];
        }
      }
      break;
    }
    case PTPRequestCodeSonyGetSDIOGetExtDeviceInfo: {
      unsigned short *codes = (unsigned short *)data.bytes;
      long count = data.length / 2;
      if (self.info.operationsSupported == nil)
        self.info.operationsSupported = [NSMutableArray array];
      if (self.info.eventsSupported == nil)
        self.info.eventsSupported = [NSMutableArray array];
      if (self.info.propertiesSupported == nil)
        self.info.propertiesSupported = [NSMutableArray array];
      for (int i = 1; i < count; i++) {
        unsigned short code = codes[i];
        if ((code & 0x7000) == 0x1000) {
          [(NSMutableArray *)self.info.operationsSupported addObject:[NSNumber numberWithUnsignedShort:code]];
        } else if ((code & 0x7000) == 0x4000) {
          [(NSMutableArray *)self.info.eventsSupported addObject:[NSNumber numberWithUnsignedShort:code]];
        } else if ((code & 0x7000) == 0x5000) {
          [(NSMutableArray *)self.info.propertiesSupported addObject:[NSNumber numberWithUnsignedShort:code]];
        }
      }
      [self sendPTPRequest:PTPRequestCodeSonySDIOConnect param1:3 param2:0 param3:0];
      [self sendPTPRequest:PTPRequestCodeSonyGetAllDevicePropData];
      [self sendPTPRequest:PTPRequestCodeGetStorageIDs];
      break;
    }
    case PTPRequestCodeSonyGetDevicePropDesc: {
      break;
    }
    case PTPRequestCodeSonyGetAllDevicePropData: {
      unsigned char* buffer = (unsigned char*)data.bytes;
      unsigned char* buf = buffer;
      unsigned int count = ptpReadUnsignedInt(&buf);
      ptpReadUnsignedInt(&buf);
      NSMutableArray *properties = [NSMutableArray array];
      for (int i = 0; i < count; i++) {
        PTPProperty *property = ptpReadSonyProperty(&buf);
        NSNumber *codeNumber = [NSNumber numberWithUnsignedShort:property.propertyCode];
        if (property.propertyCode == PTPPropertyCodeExposureProgramMode)
          mode = property.value.intValue;
        self.info.properties[codeNumber] = property;
        [properties addObject:property];
      }
      if (iteratedProperty == 0) {
        for (PTPProperty *property in properties)
          [self processPropertyDescription:property];
      }
      break;
    }
    case PTPRequestCodeSonySetControlDeviceA: {
      break;
    }
    case PTPRequestCodeSonySetControlDeviceB: {
      break;
    }
    case PTPRequestCodeGetObjectInfo: {
      unsigned short *buf = (unsigned short *)data.bytes;
      format = buf[2];
      [self sendPTPRequest:PTPRequestCodeGetObject param1:request.parameter1];
      break;
    }
    case PTPRequestCodeGetObject: {
      if (format == 0x3801)
        [self.delegate cameraExposureDone:self data:data filename:@"image.jpeg"];
      else if (format == 0xb101)
        [self.delegate cameraExposureDone:self data:data filename:@"image.arw"];
      if (--imageCount > 0)
        [self sendPTPRequest:PTPRequestCodeGetObjectInfo param1:request.parameter1];
      break;
    }
    default: {
      [super processRequest:request Response:response inData:data];
      break;
    }
  }
}

-(void)setProperty:(PTPPropertyCode)code operation:(PTPRequestCode)requestCode value:(NSString *)value {
  PTPProperty *property = self.info.properties[[NSNumber numberWithUnsignedShort:code]];
  if (property) {
    switch (property.type) {
      case PTPDataTypeCodeSInt8: {
        unsigned char *buffer = malloc(sizeof (char));
        unsigned char *buf = buffer;
        ptpWriteChar(&buf, (char)value.longLongValue);
        [self sendPTPRequest:requestCode param1:code data:[NSData dataWithBytes:buffer length:sizeof (char)]];
        free(buffer);
        break;
      }
      case PTPDataTypeCodeUInt8: {
        unsigned char *buffer = malloc(sizeof (unsigned char));
        unsigned char *buf = buffer;
        ptpWriteUnsignedChar(&buf, (unsigned char)value.longLongValue);
        [self sendPTPRequest:requestCode param1:code data:[NSData dataWithBytes:buffer length:sizeof (unsigned char)]];
        free(buffer);
        break;
      }
      case PTPDataTypeCodeSInt16: {
        unsigned char *buffer = malloc(sizeof (short));
        unsigned char *buf = buffer;
        ptpWriteShort(&buf, (short)value.longLongValue);
        [self sendPTPRequest:requestCode param1:code data:[NSData dataWithBytes:buffer length:sizeof (short)]];
        free(buffer);
        break;
      }
      case PTPDataTypeCodeUInt16: {
        unsigned char *buffer = malloc(sizeof (unsigned short));
        unsigned char *buf = buffer;
        ptpWriteUnsignedShort(&buf, (unsigned short)value.longLongValue);
        [self sendPTPRequest:requestCode param1:code data:[NSData dataWithBytes:buffer length:sizeof (unsigned short)]];
        free(buffer);
        break;
      }
      case PTPDataTypeCodeSInt32: {
        unsigned char *buffer = malloc(sizeof (int));
        unsigned char *buf = buffer;
        ptpWriteInt(&buf, (int)value.longLongValue);
        [self sendPTPRequest:requestCode param1:code data:[NSData dataWithBytes:buffer length:sizeof (int)]];
        free(buffer);
        break;
      }
      case PTPDataTypeCodeUInt32: {
        unsigned char *buffer = malloc(sizeof (unsigned int));
        unsigned char *buf = buffer;
        ptpWriteUnsignedInt(&buf, (unsigned int)value.longLongValue);
        [self sendPTPRequest:requestCode param1:code data:[NSData dataWithBytes:buffer length:sizeof (unsigned int)]];
        free(buffer);
        break;
      }
      case PTPDataTypeCodeSInt64: {
        unsigned char *buffer = malloc(sizeof (long));
        unsigned char *buf = buffer;
        ptpWriteLong(&buf, (long)value.longLongValue);
        [self sendPTPRequest:requestCode param1:code data:[NSData dataWithBytes:buffer length:sizeof (long)]];
        free(buffer);
        break;
      }
      case PTPDataTypeCodeUInt64: {
        unsigned char *buffer = malloc(sizeof (unsigned long));
        unsigned char *buf = buffer;
        ptpWriteUnsignedLong(&buf, (unsigned long)value.longLongValue);
        [self sendPTPRequest:requestCode param1:code data:[NSData dataWithBytes:buffer length:sizeof (unsigned long)]];
        free(buffer);
        break;
      }
      case PTPDataTypeCodeUnicodeString: {
        unsigned char *buffer = malloc(256);
        unsigned char *buf = buffer;
        int length = ptpWriteString(&buf, value);
        [self sendPTPRequest:requestCode param1:code data:[NSData dataWithBytes:buffer length:length]];
        free(buffer);
        break;
      }
    }
  }
}

#define MAX_WAIT  10

-(void)iterate:(PTPPropertyCode)code to:(NSString *)value withMap:(long *)map {
  iteratedProperty = code;
  PTPProperty *property = self.info.properties[[NSNumber numberWithUnsignedShort:code]];
  int current = property.value.intValue;
  int requested = value.intValue;
  int wait;
  for (int i = 0; map[i] != -1; i++)
    if (current == map[i]) {
      current = i;
      break;
    }
  for (int i = 0; map[i] != -1; i++)
    if (requested == map[i]) {
      requested = i;
      break;
    }
  if (current < requested)
    for (int i = current; i < requested; i++) {
      [self setProperty:code operation:PTPRequestCodeSonySetControlDeviceB value:@"1"];
      for (wait = 0; wait < MAX_WAIT; wait++) {
        [self sendPTPRequest:PTPRequestCodeSonyGetAllDevicePropData];
        usleep(200000);
        property = self.info.properties[[NSNumber numberWithUnsignedShort:code]];
        if (property.value.intValue == map[i + 1]) {
          break;
        }
      }
      if (wait == MAX_WAIT)
        break;
    }
  else if (current > requested)
    for (int i = current; i > requested; i--) {
      [self setProperty:code operation:PTPRequestCodeSonySetControlDeviceB value:@"-1"];
      for (wait = 0; wait < MAX_WAIT; wait++) {
        [self sendPTPRequest:PTPRequestCodeSonyGetAllDevicePropData];
        usleep(200000);
        property = self.info.properties[[NSNumber numberWithUnsignedShort:code]];
        if (property.value.intValue == map[i - 1]) {
          break;
        }
      }
      if (wait == MAX_WAIT)
        break;
    }
  iteratedProperty = 0;
  [self sendPTPRequest:PTPRequestCodeSonyGetAllDevicePropData];
}

-(void)setProperty:(PTPPropertyCode)code value:(NSString *)value {
  switch (code) {
    case PTPPropertyCodeFNumber: {
      long map[] = { 350, 400, 450, 500, 560, 630, 710, 800, 900, 1000, 1100, 1300, 1400, 1600, 1800, 2000, 2200, -1 };
      [self iterate:code to:value withMap:map];
      break;
    }
    case PTPPropertyCodeSonyShutterSpeed: {
      long map[] = { 0, 19660810, 16384010, 13107210, 9830410, 8519690, 6553610, 5242890, 3932170, 3276810, 2621450, 2097162, 1638410, 1310730, 1048586, 851978, 655370, 524298, 393226, 327690, 262154, 65539, 65540, 65541, 65542, 65544, 65546, 65549, 65551, 65556, 65561, 65566, 65576, 65586, 65596, 65616, 65636, 65661, 65696, 65736, 65786, 65856, 65936, 66036, 66176, 66336, 66536, 66786, 67136, 67536, 68036, 68736, 69536, -1 };
      [self iterate:code to:value withMap:map];
      break;
    }
    case PTPPropertyCodeSonyISO: {
      long map[] = { 16777215, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800, 16000, -1 };
      [self iterate:code to:value withMap:map];
      break;
    }
    case PTPPropertyCodeSonyDPCCompensation:
    case PTPPropertyCodeExposureBiasCompensation: {
        //      long map[] = { -5000, -4700, -4500, -4300, -4000, -3700, -3500, -3300, -3000, -2700, -2500, -2300, -2000, -1700, -1500, -1300, -1000, -700, -500, -300, 0, 300, 500, 700, 1000, 1300, 1500, 1700, 2000, 2300, 2500, 2700, 3000, 3300, 3500, 3700, 4000, 4300, 4500, 4700, 5000, -1 };
      long map[] = { -5000, -4700, -4300, -4000, -3700, -3300, -3000, -2700, -2300, -2000, -1700, -1300, -1000, -700, -300, 0, 300, 700, 1000, 1300, 1700, 2000, 2300, 2700, 3000, 3300, 3700, 4000, 4300, 4700, 5000, -1 };
      [self iterate:code to:value withMap:map];
      break;
    }
    case PTPPropertyCodeSonyCapture:
    case PTPPropertyCodeSonyAutofocus: {
      [self setProperty:code operation:PTPRequestCodeSonySetControlDeviceB value:value];
      break;
    }
    default: {
      [self setProperty:code operation:PTPRequestCodeSonySetControlDeviceA value:value];
      break;
    }
  }
}

-(void)requestEnableTethering {
}

-(void)getPreviewImage {
}

-(void)lock {
}

-(void)unlock {
}

-(void)startPreview {

}

-(void)stopPreview {
}

-(void)startAutofocus {
  [self setProperty:PTPPropertyCodeSonyAutofocus value:@"2"];
}

-(void)stopAutofocus {
  [self setProperty:PTPPropertyCodeSonyAutofocus value:@"1"];
}

-(void)startExposure {
  waitForCapture = true;
  [self setProperty:PTPPropertyCodeSonyAutofocus value:@"2"];
  if (focusMode == 1) {
    [self setProperty:PTPPropertyCodeSonyCapture value:@"2"];
    if (shutterSpeed) {
      waitForCapture = false;
      [self setProperty:PTPPropertyCodeSonyCapture value:@"1"];
      [self setProperty:PTPPropertyCodeSonyAutofocus value:@"1"];
    }
  }
}

-(void)stopExposure {
  waitForCapture = false;
  [self setProperty:PTPPropertyCodeSonyCapture value:@"1"];
  [self setProperty:PTPPropertyCodeSonyAutofocus value:@"1"];
  if (compression == 19)
    imageCount = 2;
  else
    imageCount = 1;
  [self sendPTPRequest:PTPRequestCodeGetObjectInfo param1:0xFFFFC001];
}

-(void)focus:(int)steps {
}

@end
