import os, { EventKind } from "cc/os";
import parallel from "cc/parallel";
import { IP, IPMessageEvent, UDP } from "./api";

let shouldExit = false;

while (!shouldExit) {
  parallel.waitForAny(
    // process should terminate
    () => {
      os.event(EventKind.Terminate, true);
      shouldExit = true;
      print('Aborting...');
    },

    //
    () => {
      const event = os.customEvent(IP.EVENT);

      if (UDP.isUDPMessageEvent(event[1])) {
        handleUDPEvent(event[1]);
      } else if (IP.isIPMessageEvent(event[1])) {
        handleIPEvent(event[1]);
      }
    },
  );
}

function handleIPEvent(event: IPMessageEvent) {
  throw "not implemented yet";
}
