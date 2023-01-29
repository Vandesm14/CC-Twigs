/**
 * This is being compiled into Lua for use in ComputerCraft.
 */
const args = [...$vararg];

const pluralize = (n: number, singular: string, plural?: string): string => {
  if (n === 1) {
    return `${n} ${singular}`;
  }
  return `${n} ${plural || singular + 's'}`;
};

// Find modems
const modems = [];
for (const modem of peripheral.getNames()) {
  if (peripheral.getType(modem)[0] === 'modem') {
    modems.push(modem);
  }
}
if (modems.length === 0) {
  print('No modems found.');
  // @ts-expect-error: Lua allows this
  return;
} else {
  print(`${modems.length} ${pluralize(modems.length, 'modem')} found.`);
}

const open = (channel: number) => {
  for (const modem of modems) {
    peripheral.call(modem, 'open', channel);
  }
};

const close = (channel: number) => {
  for (const modem of modems) {
    peripheral.call(modem, 'close', channel);
  }
};

// Open channels
print('0 messages repeated.');
open(rednet.CHANNEL_REPEAT);

// Main loop (terminate to break)
try {
  let receivedMessages = {};
  let receivedMessageTimeouts = {};
  let transmittedMessages = 0;

  while (true) {
    const event = os.pullEvent();
    const [eventName, modem, channel, replyChannel, message] = event;

    if (eventName === 'modem_message') {
      // Got a modem message, rebroadcast it if it's a rednet thing
      if (channel === rednet.CHANNEL_REPEAT) {
        if (
          typeof message === 'object' &&
          message.nMessageID &&
          message.nRecipient &&
          typeof message.nRecipient === 'number'
        ) {
          if (!receivedMessages[message.nMessageID]) {
            // Ensure we only repeat a message once
            receivedMessages[message.nMessageID] = true;
            receivedMessageTimeouts[os.startTimer(30)] = message.nMessageID;

            let recipient_channel = message.nRecipient;
            if (message.nRecipient !== rednet.CHANNEL_BROADCAST) {
              // @ts-expect-error: TODO: I'm not sure if this exists
              recipient_channel = recipient_channel % rednet.MAX_ID_CHANNELS;
            }

            // Send on all other open modems, to the target and to other repeaters
            for (let n = 0; n < modems.length; n++) {
              const otherModem = modems[n];
              peripheral.call(
                otherModem,
                'transmit',
                rednet.CHANNEL_REPEAT,
                replyChannel,
                message
              );
              peripheral.call(
                otherModem,
                'transmit',
                recipient_channel,
                replyChannel,
                message
              );
            }

            // Log the event
            let [_, y] = term.getCursorPos();
            term.setCursorPos(1, y - 1);
            term.clearLine();
            print(`${pluralize(transmittedMessages, 'message')} repeated.`);
          }
        }
      }
    }
  }
} catch (error) {
  print(error);
}

// Close channels
close(rednet.CHANNEL_REPEAT);
