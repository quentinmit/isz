{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    (perl.withPackages (ps: with ps; [
      AuthenSASL
      CGI
      Clone
      CompressRawBzip2
      CompressRawLzma
      CompressRawZlib
      DataDump
      #DevelRepl
      DigestHMAC
      DigestSHA1
      Error
      FileSlurper
      GSSAPI
      IO
      IOCompress
      #IOCompressBrotli
      IOSocketInet6
      JSON
      NetSMTPSSL
      SOAPLite
      Socket6
      TermReadKey
      TermReadLineGnu
      TimeHiRes
      TimeLocal
      #UTF8All
      XMLParser
      file-rename
    ]))
  ];
}
