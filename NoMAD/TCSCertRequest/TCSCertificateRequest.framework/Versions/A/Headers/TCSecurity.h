//
//  TCSecurity.h
//  SMIME Reader
//
//  
//  Copyright 2012-2017 Twocanoes Software Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Security/Security.h>

@interface TCSecurity : NSObject {

}

+(NSData *)wrappedSignature:(NSData *)inSignature;
+(NSData *)wrappedPublicKeyFromModulus:(NSData *)inModulus andExponent:(NSData *)inExponent;
+ (NSData *)sha512:(NSData *)data ;
+ (NSData *)sha256:(NSData *)data ;
+ (NSData *)signBytes:(NSData *)inData withPrivateKey:(SecKeyRef)privateKey withAlgorithm:(SecKeyAlgorithm)algorithm ;

//+(NSData *)convertPEMtoDER:(NSString *)inPEM;
+(void)addKeyToKeychain:(SecKeyRef)inKey withLabel:(NSString *)inLabel;
+(NSData *)wrappedPublicKeyFromSecKeyRef:(SecKeyRef)inPublicKey;
+(NSData *)generatePublicKeyFromPrivateKey:(SecKeyRef)privateKey;
+(SecKeyRef)generatePrivateKeyWithIdentifer:(NSString *)inIdentifer keySize:(int)keySize appPathsToTrust:(NSArray *)appPathsToTrust keychain:(NSString *)keychainPath useSystemKeychain:(BOOL)useSystemKeychain;
+(int)installCertificate:(NSData *)inCert keychain:(NSString *)keychainPath useSystemDomain:(BOOL)useSystemDomain error:(NSError **)returnErr;
+(int)installCertificate:(NSData *)inCert keychain:(NSString *)keychainPath useSystemDomain:(BOOL)useSystemDomain ssidArray:(NSArray *)ssids eapolEthernet:(BOOL)useEapolDefault error:(NSError **)returnErr;
+(int)installCertificate:(NSData *)inCert keychain:(NSString *)keychainPath useSystemDomain:(BOOL)useSystemDomain outCertificate:(SecCertificateRef *)keychain_cert ssidArray:(NSArray *)ssidArray eapolEthernet:(BOOL)useEapolDefault error:(NSError **)returnErr;
@end
