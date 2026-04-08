{ lib, pkgs, config, options, ...}@args:
let
  cfg = config.isz.telegraf.macsnmp;
in {
  options = with lib; {
    isz.telegraf.macsnmp = let trg = with types; submodule {
      options = {
        ip = mkOption { type = str; };
      };
    }; in {
      targets = mkOption {
        default = [];
        type = with types; listOf trg;
      };
    };
  };
  config.services.telegraf.extraConfig = lib.mkIf (cfg.targets != []) {
    agent.snmp_translator = "gosmi";
    inputs.snmp = map (host: {
      alias = "macsnmp_${host.ip}";
      labels.type = "macsnmp";
      agents = [ "${host.ip}:161" ];
      version = 1;
      interval = "60s";
      timeout = "10s";
      retries = 1;

      path = [
        "${pkgs.runCommand "macsnmp-mibs" {} ''
          mkdir $out
          cp "${pkgs.cisco-mibs}/v2/"{SNMPv2-MIB,IP-MIB,TCP-MIB,UDP-MIB}.my $out/
        ''}"
        "${./mibs}"
      ];

      name_prefix = "mac";

      field = [
        { name = "hostname"; oid = "SNMPv2-MIB::sysName.0"; is_tag = true; }

        {
          name = "sysUpTime";
          oid = "SNMPv2-MIB::sysUpTime.0";
          # TODO: conversion = "float(2)";
        }

        { name = "ddpOutRequests"; oid = "RFC1243-MIB::ddpOutRequests.0"; }
        { name = "ddpOutShorts"; oid = "RFC1243-MIB::ddpOutShorts.0"; }
        { name = "ddpOutLongs"; oid = "RFC1243-MIB::ddpOutLongs.0"; }
        { name = "ddpInReceives"; oid = "RFC1243-MIB::ddpInReceives.0"; }
        { name = "ddpForwRequests"; oid = "RFC1243-MIB::ddpForwRequests.0"; }
        { name = "ddpInLocalDatagrams"; oid = "RFC1243-MIB::ddpInLocalDatagrams.0"; }
        { name = "ddpNoProtocolHandlers"; oid = "RFC1243-MIB::ddpNoProtocolHandlers.0"; }
        { name = "ddpOutNoRoutes"; oid = "RFC1243-MIB::ddpOutNoRoutes.0"; }
        { name = "ddpTooShortErrors"; oid = "RFC1243-MIB::ddpTooShortErrors.0"; }
        { name = "ddpTooLongErrors"; oid = "RFC1243-MIB::ddpTooLongErrors.0"; }
        { name = "ddpBroadcastErrors"; oid = "RFC1243-MIB::ddpBroadcastErrors.0"; }
        { name = "ddpShortDDPErrors"; oid = "RFC1243-MIB::ddpShortDDPErrors.0"; }
        { name = "ddpHopCountErrors"; oid = "RFC1243-MIB::ddpHopCountErrors.0"; }
        { name = "ddpChecksumErrors"; oid = "RFC1243-MIB::ddpChecksumErrors.0"; }

        { name = "aepRequests"; oid = "RFC1243-MIB::aepRequests.0"; }
        { name = "aepReplies"; oid = "RFC1243-MIB::aepReplies.0"; }

        { name = "ipInReceives"; oid = "IP-MIB::ipInReceives.0"; }
        { name = "ipInHdrErrors"; oid = "IP-MIB::ipInHdrErrors.0"; }
        { name = "ipInAddrErrors"; oid = "IP-MIB::ipInAddrErrors.0"; }
        { name = "ipForwDatagrams"; oid = "IP-MIB::ipForwDatagrams.0"; }
        { name = "ipInUnknownProtos"; oid = "IP-MIB::ipInUnknownProtos.0"; }
        { name = "ipInDiscards"; oid = "IP-MIB::ipInDiscards.0"; }
        { name = "ipInDelivers"; oid = "IP-MIB::ipInDelivers.0"; }
        { name = "ipOutRequests"; oid = "IP-MIB::ipOutRequests.0"; }
        { name = "ipOutDiscards"; oid = "IP-MIB::ipOutDiscards.0"; }
        { name = "ipOutNoRoutes"; oid = "IP-MIB::ipOutNoRoutes.0"; }
        { name = "ipReasmReqds"; oid = "IP-MIB::ipReasmReqds.0"; }
        { name = "ipReasmOKs"; oid = "IP-MIB::ipReasmOKs.0"; }
        { name = "ipReasmFails"; oid = "IP-MIB::ipReasmFails.0"; }
        { name = "ipFragOKs"; oid = "IP-MIB::ipFragOKs.0"; }
        { name = "ipFragFails"; oid = "IP-MIB::ipFragFails.0"; }
        { name = "ipFragCreates"; oid = "IP-MIB::ipFragCreates.0"; }

        { name = "icmpInMsgs"; oid = "IP-MIB::icmpInMsgs.0"; }
        { name = "icmpInErrors"; oid = "IP-MIB::icmpInErrors.0"; }
        { name = "icmpInDestUnreachs"; oid = "IP-MIB::icmpInDestUnreachs.0"; }
        { name = "icmpInTimeExcds"; oid = "IP-MIB::icmpInTimeExcds.0"; }
        { name = "icmpInParmProbs"; oid = "IP-MIB::icmpInParmProbs.0"; }
        { name = "icmpInSrcQuenchs"; oid = "IP-MIB::icmpInSrcQuenchs.0"; }
        { name = "icmpInRedirects"; oid = "IP-MIB::icmpInRedirects.0"; }
        { name = "icmpInEchos"; oid = "IP-MIB::icmpInEchos.0"; }
        { name = "icmpInEchoReps"; oid = "IP-MIB::icmpInEchoReps.0"; }
        { name = "icmpInTimestamps"; oid = "IP-MIB::icmpInTimestamps.0"; }
        { name = "icmpInTimestampReps"; oid = "IP-MIB::icmpInTimestampReps.0"; }
        { name = "icmpInAddrMasks"; oid = "IP-MIB::icmpInAddrMasks.0"; }
        { name = "icmpInAddrMaskReps"; oid = "IP-MIB::icmpInAddrMaskReps.0"; }
        { name = "icmpOutMsgs"; oid = "IP-MIB::icmpOutMsgs.0"; }
        { name = "icmpOutErrors"; oid = "IP-MIB::icmpOutErrors.0"; }
        { name = "icmpOutDestUnreachs"; oid = "IP-MIB::icmpOutDestUnreachs.0"; }
        { name = "icmpOutTimeExcds"; oid = "IP-MIB::icmpOutTimeExcds.0"; }
        { name = "icmpOutParmProbs"; oid = "IP-MIB::icmpOutParmProbs.0"; }
        { name = "icmpOutSrcQuenchs"; oid = "IP-MIB::icmpOutSrcQuenchs.0"; }
        { name = "icmpOutRedirects"; oid = "IP-MIB::icmpOutRedirects.0"; }
        { name = "icmpOutEchos"; oid = "IP-MIB::icmpOutEchos.0"; }
        { name = "icmpOutEchoReps"; oid = "IP-MIB::icmpOutEchoReps.0"; }
        { name = "icmpOutTimestamps"; oid = "IP-MIB::icmpOutTimestamps.0"; }
        { name = "icmpOutTimestampReps"; oid = "IP-MIB::icmpOutTimestampReps.0"; }
        { name = "icmpOutAddrMasks"; oid = "IP-MIB::icmpOutAddrMasks.0"; }
        { name = "icmpOutAddrMaskReps"; oid = "IP-MIB::icmpOutAddrMaskReps.0"; }

        { name = "tcpActiveOpens"; oid = "TCP-MIB::tcpActiveOpens.0"; }
        { name = "tcpPassiveOpens"; oid = "TCP-MIB::tcpPassiveOpens.0"; }
        { name = "tcpAttemptFails"; oid = "TCP-MIB::tcpAttemptFails.0"; }
        { name = "tcpEstabResets"; oid = "TCP-MIB::tcpEstabResets.0"; }
        { name = "tcpCurrEstab"; oid = "TCP-MIB::tcpCurrEstab.0"; }
        { name = "tcpInSegs"; oid = "TCP-MIB::tcpInSegs.0"; }
        { name = "tcpOutSegs"; oid = "TCP-MIB::tcpOutSegs.0"; }
        { name = "tcpRetransSegs"; oid = "TCP-MIB::tcpRetransSegs.0"; }
        { name = "tcpInErrs"; oid = "TCP-MIB::tcpInErrs.0"; }
        { name = "tcpOutRsts"; oid = "TCP-MIB::tcpOutRsts.0"; }

        { name = "udpInDatagrams"; oid = "UDP-MIB::udpInDatagrams.0"; }
        { name = "udpNoPorts"; oid = "UDP-MIB::udpNoPorts.0"; }
        { name = "udpInErrors"; oid = "UDP-MIB::udpInErrors.0"; }
        { name = "udpOutDatagrams"; oid = "UDP-MIB::udpOutDatagrams.0"; }

        { name = "snmpInPkts"; oid = "SNMPv2-MIB::snmpInPkts.0"; }
        { name = "snmpOutPkts"; oid = "SNMPv2-MIB::snmpOutPkts.0"; }
        { name = "snmpInBadVersions"; oid = "SNMPv2-MIB::snmpInBadVersions.0"; }
        { name = "snmpInBadCommunityNames"; oid = "SNMPv2-MIB::snmpInBadCommunityNames.0"; }
        { name = "snmpInBadCommunityUses"; oid = "SNMPv2-MIB::snmpInBadCommunityUses.0"; }
        { name = "snmpInASNParseErrs"; oid = "SNMPv2-MIB::snmpInASNParseErrs.0"; }
        { name = "snmpInTooBigs"; oid = "SNMPv2-MIB::snmpInTooBigs.0"; }
        { name = "snmpInNoSuchNames"; oid = "SNMPv2-MIB::snmpInNoSuchNames.0"; }
        { name = "snmpInBadValues"; oid = "SNMPv2-MIB::snmpInBadValues.0"; }
        { name = "snmpInReadOnlys"; oid = "SNMPv2-MIB::snmpInReadOnlys.0"; }
        { name = "snmpInGenErrs"; oid = "SNMPv2-MIB::snmpInGenErrs.0"; }
        { name = "snmpInTotalReqVars"; oid = "SNMPv2-MIB::snmpInTotalReqVars.0"; }
        { name = "snmpInTotalSetVars"; oid = "SNMPv2-MIB::snmpInTotalSetVars.0"; }
        { name = "snmpInGetRequests"; oid = "SNMPv2-MIB::snmpInGetRequests.0"; }
        { name = "snmpInGetNexts"; oid = "SNMPv2-MIB::snmpInGetNexts.0"; }
        { name = "snmpInSetRequests"; oid = "SNMPv2-MIB::snmpInSetRequests.0"; }
        { name = "snmpInGetResponses"; oid = "SNMPv2-MIB::snmpInGetResponses.0"; }
        { name = "snmpInTraps"; oid = "SNMPv2-MIB::snmpInTraps.0"; }
        { name = "snmpOutTooBigs"; oid = "SNMPv2-MIB::snmpOutTooBigs.0"; }
        { name = "snmpOutNoSuchNames"; oid = "SNMPv2-MIB::snmpOutNoSuchNames.0"; }
        { name = "snmpOutBadValues"; oid = "SNMPv2-MIB::snmpOutBadValues.0"; }
        { name = "snmpOutGenErrs"; oid = "SNMPv2-MIB::snmpOutGenErrs.0"; }
        { name = "snmpOutGetRequests"; oid = "SNMPv2-MIB::snmpOutGetRequests.0"; }
        { name = "snmpOutGetNexts"; oid = "SNMPv2-MIB::snmpOutGetNexts.0"; }
        { name = "snmpOutSetRequests"; oid = "SNMPv2-MIB::snmpOutSetRequests.0"; }
        { name = "snmpOutGetResponses"; oid = "SNMPv2-MIB::snmpOutGetResponses.0"; }
        { name = "snmpOutTraps"; oid = "SNMPv2-MIB::snmpOutTraps.0"; }

      ];

      table = [
        { # Volumes
          name = "snmp-volumes";
          inherit_tags = ["hostname"];
          field = [
            { name = "refNum"; oid = "Apple-Macintosh-System-MIB::volRefNum"; is_tag = true; }
            { name = "name"; oid = "Apple-Macintosh-System-MIB::volName"; is_tag = true; }
            { name = "kind"; oid = "Apple-Macintosh-System-MIB::volKind"; is_tag = true; }
            { name = "location"; oid = "Apple-Macintosh-System-MIB::volLocation"; is_tag = true; }

            { name = "bytesUsed"; oid = "Apple-Macintosh-System-MIB::volBytesUsed"; }
            { name = "bytesFree"; oid = "Apple-Macintosh-System-MIB::volBytesFree"; }
          ];
        }
        { # RTMP
          name = "snmp-appletalk-routes";
          inherit_tags = ["hostname"];
          field = [
            { name = "rangeStart"; oid = "RFC1243-MIB::rtmpRangeStart"; conversion = "hextoint:BigEndian:uint16"; is_tag = true; }
            { name = "rangeEnd"; oid = "RFC1243-MIB::rtmpRangeEnd"; conversion = "hextoint:BigEndian:uint16"; is_tag = true; }
            { name = "type"; oid = "RFC1243-MIB::rtmpType"; is_tag = true; }
            { name = "zone"; oid = "RFC1243-MIB::zipZoneName"; oid_index_length = 2; is_tag = true; }
            { name = "nextHop"; conversion = "hex"; oid = "RFC1243-MIB::rtmpNextHop"; }
            { name = "port"; oid = "RFC1243-MIB::rtmpPort"; }
            { name = "hops"; oid = "RFC1243-MIB::rtmpHops"; }
            { name = "state"; oid = "RFC1243-MIB::rtmpState"; }
          ];
        }
      ];
    }) cfg.targets;
    processors.starlark = [
      {
        namepass = ["macsnmp-appletalk-routes"];

        source = ''
          def apply(metric):
            if "rangeEnd" in metric.tags and "rangeStart" in metric.tags and metric.tags["rangeEnd"] == "0":
              metric.tags["rangeEnd"] = metric.tags["rangeStart"]
            if "type" in metric.tags and "nextHop" in metric.fields:
              h = metric.fields["nextHop"]
              t = metric.tags["type"]
              if t == "2":
                # AppleTalk
                h = "%s.%s" % (h[:4], h[4:])
              elif t == "1":
                # Other (IP)
                h = "%d.%d.%d.%d" % tuple([int(h[i:i+2], 16) for i in range(0, 8, 2)])
              metric.fields["nextHop"] = h
            return [metric]
        '';
      }
    ];
  };
}
