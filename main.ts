const args = [...$vararg];

const pluralize = (n: number, singular: string, plural?: string): string =>
  n === 1 ? `${n} ${singular}` : `${n} ${plural || singular + 's'}`;

function getModems(): string[] {
  const modems = peripheral
    .getNames()
    .filter((name) => peripheral.getType(name)[0] === 'modem');
  if (modems.length === 0) {
    print('No modems found.');
    shell.exit();
  } else {
    print(`${pluralize(modems.length, 'modem')} found.`);
  }

  return modems;
}

function open(modems: string[], channel: number) {
  for (const modem of modems) {
    peripheral.call(modem, 'open', channel);
  }
}
function close(modems: string[], channel: number) {
  for (const modem of modems) {
    peripheral.call(modem, 'close', channel);
  }
}

const setup = (modems: string[]) => open(modems, rednet.CHANNEL_REPEAT);
const takedown = (modems: string[]) => close(modems, rednet.CHANNEL_REPEAT);

function listen(modems: string[]) {
  // Open channels
  print('0 messages repeated.');

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
              transmittedMessages++;
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
}

function run() {
  const modems = getModems();

  // Setup channels
  setup(modems);

  // Listen for messages
  listen(modems);

  // After listening, close channels
  takedown(modems);
}

run();
